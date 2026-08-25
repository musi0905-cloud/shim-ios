//
//  DefaultAudioService.swift
//  Shim
//
//  AudioService 의 기본 구현.
//
//  이 타입은 AVFoundation 을 import 하지 않는다. `AudioPlayerProviding` 과
//  `AudioSessionConfiguring` 에만 의존하므로 테스트에서 실제 소리를 내지 않고
//  prepare / play / stop / 중복 호출 / 실패 경로를 결정적으로 검증할 수 있다.
//

import Foundation

@MainActor
final class DefaultAudioService: AudioService {

    private let provider: AudioPlayerProviding
    private let session: AudioSessionConfiguring

    private var player: AudioPlayerEngine?
    private var preparedMode: AudioMode?

    /// interruption 직전에 재생 중이었는지. 재개 판단에 쓴다.
    private var wasPlayingBeforeInterruption = false

    private(set) var isPlaying = false

    /// 준비는 됐지만 재생할 소리가 없는 상태(무음 모드)인지.
    private var isSilentMode: Bool {
        preparedMode != nil && player == nil
    }

    init(provider: AudioPlayerProviding? = nil,
         session: AudioSessionConfiguring? = nil) {
        self.provider = provider ?? BundleAudioPlayerProvider()
        self.session = session ?? AVAudioSessionConfigurator()
        bindSessionEvents()
    }

    // MARK: - AudioService

    func prepare(mode: AudioMode) async throws {
        // 이전 재생이 남아 있으면 먼저 정리한다.
        teardownPlayer()

        preparedMode = mode

        // 무음 모드는 만들 플레이어가 없다. 오류가 아니다.
        guard let engine = try provider.makePlayer(for: mode) else {
            player = nil
            return
        }

        engine.numberOfLoops = -1   // 30초 테스트 음원을 쉼 내내 반복한다
        engine.volume = 1.0         // 음원 자체가 이미 낮은 레벨이다

        guard engine.prepareToPlay() else {
            player = nil
            throw AudioServiceError.preparationFailed
        }

        player = engine
    }

    func play() async throws {
        guard preparedMode != nil else {
            throw AudioServiceError.notPrepared
        }

        // 무음 모드: 할 일이 없다. 오류도 아니다.
        guard let player else { return }

        // 중복 play 는 무시한다. 두 번 재생되지 않는다.
        guard !isPlaying else { return }

        do {
            try session.activatePlayback()
        } catch {
            throw AudioServiceError.sessionActivationFailed(
                reason: error.localizedDescription
            )
        }

        guard player.play() else {
            throw AudioServiceError.playbackStartFailed
        }

        isPlaying = true
        wasPlayingBeforeInterruption = false
    }

    func stop() {
        teardownPlayer()
        preparedMode = nil
        // 세션 해제 실패가 쉼 종료를 막아서는 안 된다.
        try? session.deactivate()
    }

    // MARK: - OS interruption 대응
    //
    // 사용자 UX 의 Pause 는 없다(D-014). 아래는 전화·Siri·이어폰 분리 같은
    // 시스템 이벤트에만 반응하는 내부 상태다. 사용자에게 노출되지 않는다.

    private func bindSessionEvents() {
        session.onInterruptionBegan = { [weak self] in
            self?.handleInterruptionBegan()
        }
        session.onInterruptionEnded = { [weak self] shouldResume in
            self?.handleInterruptionEnded(shouldResume: shouldResume)
        }
        session.onRouteDeviceUnavailable = { [weak self] in
            self?.handleRouteDeviceUnavailable()
        }
    }

    /// 전화가 오는 등으로 오디오가 중단됐다.
    func handleInterruptionBegan() {
        guard isPlaying, let player else { return }
        player.pause()
        isPlaying = false
        wasPlayingBeforeInterruption = true
    }

    /// interruption 이 끝났다.
    ///
    /// 시스템이 재개를 권하고(`shouldResume`) 우리가 원래 재생 중이었을 때만
    /// 다시 튼다. 사용자가 이미 쉼을 끝냈다면 `stop()` 이 상태를 지웠으므로
    /// 여기서 되살아나지 않는다.
    func handleInterruptionEnded(shouldResume: Bool) {
        defer { wasPlayingBeforeInterruption = false }

        guard shouldResume, wasPlayingBeforeInterruption, let player else { return }

        // 재개 실패는 조용히 넘긴다. 소리가 안 나는 것이 쉼을 깨뜨리지는 않는다.
        try? session.activatePlayback()
        if player.play() {
            isPlaying = true
        }
    }

    /// 이어폰이 빠졌다. 스피커로 갑자기 터져 나오지 않게 멈춘다.
    func handleRouteDeviceUnavailable() {
        guard isPlaying, let player else { return }
        player.pause()
        isPlaying = false
        wasPlayingBeforeInterruption = false
    }

    // MARK: - 내부

    private func teardownPlayer() {
        player?.stop()
        player = nil
        isPlaying = false
        wasPlayingBeforeInterruption = false
    }
}
