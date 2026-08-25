//
//  TestDoubles.swift
//  ShimTests
//
//  Sprint 2 테스트용 시계와 tick 신호.
//
//  실제 시간을 기다리지 않고 시작 직후 / 경과 / 종료 직전 / 종료 시점 /
//  종료 초과 / background 복귀를 결정적으로 재현하기 위한 것이다.
//

import Foundation
@testable import Shim

/// 손으로 앞당길 수 있는 시계.
final class MutableClock: Clock {
    private(set) var now: Date

    init(now: Date = Date(timeIntervalSince1970: 1_700_000_000)) {
        self.now = now
    }

    /// 시간을 앞으로 보낸다.
    func advance(by interval: TimeInterval) {
        now = now.addingTimeInterval(interval)
    }

    /// 분 단위로 앞으로 보낸다.
    func advance(minutes: Double) {
        advance(by: minutes * 60)
    }
}

/// 자동으로 돌지 않는 tick 신호.
///
/// 테스트가 `fire()` 를 부를 때만 tick 이 발생한다.
/// 앱이 background 에서 suspend 되어 tick 이 아예 오지 않는 상황도
/// "fire 를 부르지 않는 것"으로 그대로 재현할 수 있다.
@MainActor
final class ManualTickScheduler: TickScheduler {
    private var onTick: (() -> Void)?

    private(set) var isRunning = false
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var lastInterval: TimeInterval?

    func start(interval: TimeInterval, onTick: @escaping () -> Void) {
        startCount += 1
        lastInterval = interval
        isRunning = true
        self.onTick = onTick
    }

    func stop() {
        stopCount += 1
        isRunning = false
        onTick = nil
    }

    /// tick 을 한 번 발생시킨다. 멈춰 있으면 아무 일도 하지 않는다.
    func fire() {
        onTick?()
    }

    /// tick 을 여러 번 발생시킨다.
    func fire(times: Int) {
        for _ in 0..<times { fire() }
    }
}

// MARK: - Sprint 3: 오디오

/// 실제 소리를 내지 않는 플레이어.
final class FakeAudioPlayerEngine: AudioPlayerEngine {
    var isPlaying = false
    var numberOfLoops = 0
    var volume: Float = 0

    /// `prepareToPlay()` 가 돌려줄 값. false 로 두면 준비 실패를 재현한다.
    var prepareResult = true
    /// `play()` 가 돌려줄 값. false 로 두면 재생 시작 실패를 재현한다.
    var playResult = true

    private(set) var prepareCallCount = 0
    private(set) var playCallCount = 0
    private(set) var pauseCallCount = 0
    private(set) var stopCallCount = 0

    func prepareToPlay() -> Bool {
        prepareCallCount += 1
        return prepareResult
    }

    func play() -> Bool {
        playCallCount += 1
        if playResult { isPlaying = true }
        return playResult
    }

    func pause() {
        pauseCallCount += 1
        isPlaying = false
    }

    func stop() {
        stopCallCount += 1
        isPlaying = false
    }
}

/// 원하는 결과를 지정할 수 있는 플레이어 공급자.
@MainActor
final class FakeAudioPlayerProvider: AudioPlayerProviding {
    enum Outcome {
        /// 정상적으로 플레이어를 준다.
        case player(FakeAudioPlayerEngine)
        /// 무음 모드처럼 재생할 것이 없다.
        case silent
        /// 오류를 던진다.
        case failure(AudioServiceError)
    }

    var outcome: Outcome
    private(set) var requestedModes: [AudioMode] = []

    init(outcome: Outcome = .player(FakeAudioPlayerEngine())) {
        self.outcome = outcome
    }

    func makePlayer(for mode: AudioMode) throws -> AudioPlayerEngine? {
        requestedModes.append(mode)
        switch outcome {
        case let .player(engine): return engine
        case .silent:             return nil
        case let .failure(error): throw error
        }
    }
}

/// 실제 AVAudioSession 을 건드리지 않는 세션. 시스템 이벤트를 손으로 쏠 수 있다.
@MainActor
final class FakeAudioSession: AudioSessionConfiguring {
    var onInterruptionBegan: (() -> Void)?
    var onInterruptionEnded: ((Bool) -> Void)?
    var onRouteDeviceUnavailable: (() -> Void)?

    /// 활성화 시 던질 오류. nil 이면 성공한다.
    var activationError: Error?

    private(set) var activateCallCount = 0
    private(set) var deactivateCallCount = 0

    func activatePlayback() throws {
        activateCallCount += 1
        if let activationError { throw activationError }
    }

    func deactivate() throws {
        deactivateCallCount += 1
    }

    // 시스템 이벤트 재현
    func simulateInterruptionBegan() { onInterruptionBegan?() }
    func simulateInterruptionEnded(shouldResume: Bool) { onInterruptionEnded?(shouldResume) }
    func simulateRouteDeviceUnavailable() { onRouteDeviceUnavailable?() }
}

/// Coordinator 통합 테스트용 오디오 스텁.
@MainActor
final class SpyAudioService: AudioService {
    private(set) var isPlaying = false

    private(set) var prepareCallCount = 0
    private(set) var playCallCount = 0
    private(set) var stopCallCount = 0
    private(set) var preparedModes: [AudioMode] = []

    /// prepare 에서 던질 오류.
    var prepareError: AudioServiceError?
    /// play 에서 던질 오류.
    var playError: AudioServiceError?

    func prepare(mode: AudioMode) async throws {
        prepareCallCount += 1
        preparedModes.append(mode)
        if let prepareError { throw prepareError }
    }

    func play() async throws {
        playCallCount += 1
        if let playError { throw playError }
        isPlaying = true
    }

    func stop() {
        stopCallCount += 1
        isPlaying = false
    }
}

// MARK: - Sprint 7: 기록 저장소

/// 메모리에만 담는 기록 저장소.
@MainActor
final class InMemoryRestHistoryStore: RestHistoryStore {
    private(set) var entries: [RestHistoryEntry] = []
    private(set) var saveCallCount = 0
    private(set) var removeAllCallCount = 0

    /// true 면 저장을 조용히 실패시킨다. 저장 실패가 흐름을 막지 않는지 확인할 때 쓴다.
    var failsSilently = false

    func save(_ entry: RestHistoryEntry) {
        saveCallCount += 1
        guard !failsSilently else { return }
        entries.insert(entry, at: 0)
    }

    func recentEntries(limit: Int) -> [RestHistoryEntry] {
        guard limit > 0 else { return [] }
        return Array(entries.prefix(limit))
    }

    func removeAll() {
        removeAllCallCount += 1
        entries.removeAll()
    }
}

/// 테스트 전용 UserDefaults suite 를 만든다.
///
/// `.standard` 를 건드리면 테스트끼리 간섭한다.
@MainActor
enum TestDefaults {
    static func make(_ name: String = #function) -> UserDefaults {
        let suite = "shim.tests.\(name).\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}
