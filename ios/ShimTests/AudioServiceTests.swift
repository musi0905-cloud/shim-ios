//
//  AudioServiceTests.swift
//  ShimTests
//
//  Sprint 3 Gate A — 오디오 실행 파이프라인의 계약을 고정한다.
//
//  실제 소리를 내지 않는다. AudioPlayerProviding 과 AudioSessionConfiguring 을
//  주입해 prepare / play / stop / 중복 호출 / 실패 경로를 결정적으로 검증한다.
//
//  ⚠️ 이 테스트가 통과해도 **실기기 검증이 끝난 것이 아니다.**
//     Background Audio, 화면 잠금 재생, 실제 interruption 은 Gate B 다.
//

import XCTest
@testable import Shim

@MainActor
final class AudioServiceTests: XCTestCase {

    private var engine: FakeAudioPlayerEngine!
    private var provider: FakeAudioPlayerProvider!
    private var session: FakeAudioSession!
    private var service: DefaultAudioService!

    override func setUp() async throws {
        try await super.setUp()
        engine = FakeAudioPlayerEngine()
        provider = FakeAudioPlayerProvider(outcome: .player(engine))
        session = FakeAudioSession()
        service = DefaultAudioService(provider: provider, session: session)
    }

    override func tearDown() async throws {
        service = nil
        session = nil
        provider = nil
        engine = nil
        try await super.tearDown()
    }

    // MARK: - prepare

    func testPrepareSucceeds() async throws {
        try await service.prepare(mode: .calmAcoustic)

        XCTAssertEqual(engine.prepareCallCount, 1)
        XCTAssertEqual(provider.requestedModes, [.calmAcoustic])
        XCTAssertFalse(service.isPlaying, "준비만 했지 아직 재생하지 않았다")
    }

    /// 쉼 내내 반복되어야 한다. 30초 테스트 음원으로 10분을 채운다.
    func testPrepareConfiguresInfiniteLoop() async throws {
        try await service.prepare(mode: .calmAcoustic)
        XCTAssertEqual(engine.numberOfLoops, -1)
    }

    /// 무음 모드는 재생할 것이 없지만 오류가 아니다.
    func testSilentModePreparesWithoutError() async throws {
        provider.outcome = .silent

        try await service.prepare(mode: .silence)
        try await service.play()

        XCTAssertFalse(service.isPlaying)
        XCTAssertEqual(session.activateCallCount, 0, "무음이면 세션도 켜지 않는다")
    }

    // MARK: - play

    func testPlaySucceeds() async throws {
        try await service.prepare(mode: .calmAcoustic)
        try await service.play()

        XCTAssertTrue(service.isPlaying)
        XCTAssertEqual(engine.playCallCount, 1)
        XCTAssertEqual(session.activateCallCount, 1, "재생 전에 세션을 켠다")
    }

    /// 중복 play 는 두 번 재생하지 않는다.
    func testDuplicatePlayIsIgnored() async throws {
        try await service.prepare(mode: .calmAcoustic)
        try await service.play()
        try await service.play()
        try await service.play()

        XCTAssertEqual(engine.playCallCount, 1, "소리가 겹쳐 나면 안 된다")
        XCTAssertEqual(session.activateCallCount, 1)
        XCTAssertTrue(service.isPlaying)
    }

    func testPlayWithoutPrepareThrows() async {
        do {
            try await service.play()
            XCTFail("준비 없이 재생하면 오류여야 한다")
        } catch {
            XCTAssertEqual(error as? AudioServiceError, .notPrepared)
        }
    }

    // MARK: - stop

    func testStopSucceeds() async throws {
        try await service.prepare(mode: .calmAcoustic)
        try await service.play()

        service.stop()

        XCTAssertFalse(service.isPlaying)
        XCTAssertEqual(engine.stopCallCount, 1)
        XCTAssertEqual(session.deactivateCallCount, 1, "세션도 정리한다")
    }

    /// stop 을 여러 번 불러도 안전해야 한다.
    func testRepeatedStopIsSafe() async throws {
        try await service.prepare(mode: .calmAcoustic)
        try await service.play()

        service.stop()
        service.stop()
        service.stop()

        XCTAssertFalse(service.isPlaying)
        XCTAssertEqual(engine.stopCallCount, 1, "이미 정리된 플레이어를 다시 멈추지 않는다")
    }

    func testStopBeforeStartIsSafe() {
        service.stop()
        XCTAssertFalse(service.isPlaying)
    }

    /// stop 이후 다시 재생하려면 prepare 부터 해야 한다.
    func testPlayAfterStopRequiresPrepare() async throws {
        try await service.prepare(mode: .calmAcoustic)
        try await service.play()
        service.stop()

        do {
            try await service.play()
            XCTFail("정리된 뒤에는 준비 없이 재생할 수 없다")
        } catch {
            XCTAssertEqual(error as? AudioServiceError, .notPrepared)
        }
    }

    // MARK: - 실패 경로

    /// 지원하지 않는 모드.
    func testUnsupportedModeThrows() async {
        provider.outcome = .failure(.unsupportedMode(.natureSound))

        do {
            try await service.prepare(mode: .natureSound)
            XCTFail("지원하지 않는 모드는 오류여야 한다")
        } catch {
            XCTAssertEqual(error as? AudioServiceError, .unsupportedMode(.natureSound))
        }
        XCTAssertFalse(service.isPlaying)
    }

    /// 음원 파일이 없다.
    func testMissingResourceThrows() async {
        provider.outcome = .failure(.resourceNotFound(name: "test_ambient"))

        do {
            try await service.prepare(mode: .calmAcoustic)
            XCTFail("파일이 없으면 오류여야 한다")
        } catch {
            XCTAssertEqual(error as? AudioServiceError,
                           .resourceNotFound(name: "test_ambient"))
        }
    }

    /// 재생 초기화 실패.
    func testPreparationFailureThrows() async {
        engine.prepareResult = false

        do {
            try await service.prepare(mode: .calmAcoustic)
            XCTFail("prepareToPlay 실패는 오류여야 한다")
        } catch {
            XCTAssertEqual(error as? AudioServiceError, .preparationFailed)
        }
        XCTAssertFalse(service.isPlaying)
    }

    func testPlaybackStartFailureThrows() async throws {
        engine.playResult = false
        try await service.prepare(mode: .calmAcoustic)

        do {
            try await service.play()
            XCTFail("play 실패는 오류여야 한다")
        } catch {
            XCTAssertEqual(error as? AudioServiceError, .playbackStartFailed)
        }
        XCTAssertFalse(service.isPlaying)
    }

    func testSessionActivationFailureThrows() async throws {
        session.activationError = NSError(domain: "test", code: 1)
        try await service.prepare(mode: .calmAcoustic)

        do {
            try await service.play()
            XCTFail("세션 활성화 실패는 오류여야 한다")
        } catch {
            guard case .sessionActivationFailed = (error as? AudioServiceError) else {
                return XCTFail("sessionActivationFailed 여야 한다. 실제: \(error)")
            }
        }
        XCTAssertFalse(service.isPlaying)
        XCTAssertEqual(engine.playCallCount, 0, "세션이 안 켜졌으면 재생도 시도하지 않는다")
    }

    /// 실패한 뒤에도 정리와 재시작이 가능해야 한다. 크래시하지 않는다.
    func testCanRecoverAfterFailure() async throws {
        engine.prepareResult = false
        try? await service.prepare(mode: .calmAcoustic)
        service.stop()

        let healthy = FakeAudioPlayerEngine()
        provider.outcome = .player(healthy)

        try await service.prepare(mode: .calmAcoustic)
        try await service.play()

        XCTAssertTrue(service.isPlaying)
    }

    // MARK: - OS interruption
    //
    // 사용자 UX 의 Pause 는 없다(D-014). 아래는 전화·Siri·이어폰 분리에만
    // 반응하는 내부 동작이다.

    func testInterruptionPausesPlayback() async throws {
        try await service.prepare(mode: .calmAcoustic)
        try await service.play()

        session.simulateInterruptionBegan()

        XCTAssertFalse(service.isPlaying)
        XCTAssertEqual(engine.pauseCallCount, 1)
        XCTAssertEqual(engine.stopCallCount, 0, "중단이지 종료가 아니다")
    }

    func testInterruptionEndedResumesWhenSystemAllows() async throws {
        try await service.prepare(mode: .calmAcoustic)
        try await service.play()
        session.simulateInterruptionBegan()

        session.simulateInterruptionEnded(shouldResume: true)

        XCTAssertTrue(service.isPlaying)
        XCTAssertEqual(engine.playCallCount, 2, "다시 튼다")
    }

    func testInterruptionEndedDoesNotResumeWhenSystemDeclines() async throws {
        try await service.prepare(mode: .calmAcoustic)
        try await service.play()
        session.simulateInterruptionBegan()

        session.simulateInterruptionEnded(shouldResume: false)

        XCTAssertFalse(service.isPlaying, "시스템이 재개를 권하지 않으면 멈춘 채로 둔다")
        XCTAssertEqual(engine.playCallCount, 1)
    }

    /// 사용자가 쉼을 끝낸 뒤 interruption 이 끝나도 소리가 되살아나면 안 된다.
    func testInterruptionEndedAfterStopDoesNotRevive() async throws {
        try await service.prepare(mode: .calmAcoustic)
        try await service.play()
        session.simulateInterruptionBegan()

        service.stop()
        session.simulateInterruptionEnded(shouldResume: true)

        XCTAssertFalse(service.isPlaying, "끝난 쉼의 소리가 되살아나면 안 된다")
    }

    /// 이어폰이 빠지면 스피커로 터져 나오지 않아야 한다.
    func testHeadphoneRemovalPausesPlayback() async throws {
        try await service.prepare(mode: .calmAcoustic)
        try await service.play()

        session.simulateRouteDeviceUnavailable()

        XCTAssertFalse(service.isPlaying)
        XCTAssertEqual(engine.pauseCallCount, 1)
    }

    /// 재생 중이 아닐 때 들어온 시스템 이벤트는 아무 일도 하지 않아야 한다.
    func testSystemEventsWhileIdleAreHarmless() {
        session.simulateInterruptionBegan()
        session.simulateInterruptionEnded(shouldResume: true)
        session.simulateRouteDeviceUnavailable()

        XCTAssertFalse(service.isPlaying)
    }
}

// MARK: - 번들 리소스

@MainActor
final class AudioResourceTests: XCTestCase {

    /// 무음 모드에는 음원이 없어야 한다.
    func testSilenceHasNoResource() {
        XCTAssertNil(BundleAudioPlayerProvider.resourceName(for: .silence))
    }

    /// 소리가 나는 모드에는 음원 이름이 있어야 한다.
    func testAudibleModesHaveResourceNames() {
        XCTAssertEqual(BundleAudioPlayerProvider.resourceName(for: .calmAcoustic),
                       "test_ambient")
        XCTAssertEqual(BundleAudioPlayerProvider.resourceName(for: .natureSound),
                       "test_ambient")
    }

    /// 테스트 음원이 실제로 앱 번들에 들어가 있어야 한다.
    ///
    /// 이 테스트가 깨지면 리소스가 타깃에 포함되지 않은 것이다.
    /// 실기기에서야 발견하면 늦다.
    func testTestAudioIsBundled() throws {
        let url = try XCTUnwrap(
            Bundle.main.url(forResource: "test_ambient", withExtension: "wav"),
            "test_ambient.wav 가 앱 번들에 없다"
        )
        let size = try XCTUnwrap(
            FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int
        )
        XCTAssertGreaterThan(size, 100_000, "음원 파일이 비어 있거나 잘렸다")
    }

    /// 번들 공급자가 실제 파일로 플레이어를 만들 수 있어야 한다.
    func testBundleProviderCreatesPlayerForAudibleMode() throws {
        let provider = BundleAudioPlayerProvider()
        let player = try provider.makePlayer(for: .calmAcoustic)
        XCTAssertNotNil(player)
    }

    func testBundleProviderReturnsNilForSilence() throws {
        let provider = BundleAudioPlayerProvider()
        XCTAssertNil(try provider.makePlayer(for: .silence))
    }

    /// Background Audio capability 가 실제로 설정돼 있어야 한다.
    ///
    /// 이것이 없으면 앱이 background 로 가는 순간 소리가 끊긴다.
    /// Gate B 실기기 검증의 전제 조건이므로 CI 에서 미리 확인한다.
    func testBackgroundAudioCapabilityIsDeclared() throws {
        let modes = try XCTUnwrap(
            Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String],
            "Info.plist 에 UIBackgroundModes 가 없다"
        )
        XCTAssertTrue(modes.contains("audio"),
                      "UIBackgroundModes 에 audio 가 없다. background 재생이 안 된다. 실제: \(modes)")
    }
}
