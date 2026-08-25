//
//  RestFlowAudioIntegrationTests.swift
//  ShimTests
//
//  쉼 흐름과 오디오가 이어져 동작하는지 확인한다.
//
//      쉼 시작 → 오디오 자동 시작
//      정상 종료 → 오디오 정지
//      사용자 취소 → 오디오 정지
//      오디오 실패 → 쉼은 계속된다 (D-019)
//

import XCTest
@testable import Shim

@MainActor
final class RestFlowAudioIntegrationTests: XCTestCase {

    private var clock: MutableClock!
    private var scheduler: ManualTickScheduler!
    private var audio: SpyAudioService!
    private var coordinator: RestFlowCoordinator!

    override func setUp() async throws {
        try await super.setUp()
        clock = MutableClock()
        scheduler = ManualTickScheduler()
        audio = SpyAudioService()
        coordinator = RestFlowCoordinator(
            timer: DefaultRestTimerService(clock: clock, scheduler: scheduler),
            audio: audio,
            history: InMemoryRestHistoryStore(),
            clock: clock
        )
    }

    override func tearDown() async throws {
        coordinator = nil
        audio = nil
        scheduler = nil
        clock = nil
        try await super.tearDown()
    }

    /// 오디오 시작은 비동기라 한 틱 기다려 준다.
    private func settle() async {
        await Task.yield()
        try? await Task.sleep(nanoseconds: 20_000_000)
    }

    // MARK: - 쉼 시작 시 오디오 실행

    func testStartingRestStartsAudio() async {
        coordinator.start(with: MockRestPlanFactory.defaultPlan())
        await settle()

        XCTAssertEqual(audio.prepareCallCount, 1)
        XCTAssertEqual(audio.playCallCount, 1)
        XCTAssertTrue(audio.isPlaying)
    }

    /// RestPlan 의 audio 값이 그대로 AudioService 로 전달되어야 한다.
    func testPlanAudioModeReachesAudioService() async {
        coordinator.start(with: MockRestPlanFactory.defaultPlan())
        await settle()

        XCTAssertEqual(audio.preparedModes, [.calmAcoustic],
                       "계획의 audio 가 서비스로 전달되어야 한다")
    }

    func testSilentPlanStillPreparesAudioService() async {
        // shortPlan 은 audio 가 .silence 다.
        coordinator.start(with: MockRestPlanFactory.shortPlan(minutes: 5))
        await settle()

        XCTAssertEqual(audio.preparedModes, [.silence])
        XCTAssertNil(coordinator.audioError, "무음은 오류가 아니다")
    }

    // MARK: - 종료 시 정리

    /// 타이머가 정상 종료되면 오디오도 멈춰야 한다.
    func testAudioStopsWhenTimerCompletes() async {
        coordinator.start(with: MockRestPlanFactory.defaultPlan())
        await settle()

        clock.advance(minutes: 10)
        scheduler.fire()

        XCTAssertEqual(coordinator.state, .completed)
        XCTAssertEqual(audio.stopCallCount, 1)
        XCTAssertFalse(audio.isPlaying)
    }

    /// 사용자가 취소해도 오디오는 즉시 멈춰야 한다.
    func testAudioStopsWhenUserCancels() async {
        coordinator.start(with: MockRestPlanFactory.defaultPlan())
        await settle()

        coordinator.cancel()

        XCTAssertEqual(coordinator.state, .idle, "취소 후 즉시 홈으로 돌아간다 (D-023)")
        XCTAssertEqual(audio.stopCallCount, 1)
        XCTAssertFalse(audio.isPlaying)
    }

    /// 검증에 실패한 계획으로는 오디오도 시작되지 않아야 한다.
    func testInvalidPlanNeverStartsAudio() async {
        let invalid = RestPlan(
            durationMinutes: 0,
            restType: .environmentReset,
            audio: .calmAcoustic,
            movement: .none,
            screenMode: .minimal
        )

        coordinator.start(with: invalid)
        await settle()

        XCTAssertEqual(audio.prepareCallCount, 0)
        XCTAssertEqual(audio.playCallCount, 0)
    }

    // MARK: - 오디오 실패 (D-019)

    /// 오디오 준비가 실패해도 쉼은 계속된다. 크래시하지 않는다.
    func testAudioPrepareFailureDoesNotStopTheRest() async {
        audio.prepareError = .resourceNotFound(name: "test_ambient")

        coordinator.start(with: MockRestPlanFactory.defaultPlan())
        await settle()

        XCTAssertEqual(coordinator.state, .running, "쉼은 계속되어야 한다")
        XCTAssertEqual(coordinator.remainingSeconds, 600, accuracy: 0.001)
        XCTAssertNotNil(coordinator.audioError, "실패는 드러나야 한다")
        XCTAssertEqual(audio.playCallCount, 0)
    }

    /// 재생 시작이 실패해도 마찬가지다.
    func testAudioPlayFailureDoesNotStopTheRest() async {
        audio.playError = .playbackStartFailed

        coordinator.start(with: MockRestPlanFactory.defaultPlan())
        await settle()

        XCTAssertEqual(coordinator.state, .running)
        XCTAssertNotNil(coordinator.audioError)
    }

    /// 오디오가 실패한 쉼도 정상적으로 끝까지 간다.
    func testRestCompletesNormallyEvenWhenAudioFailed() async {
        audio.prepareError = .preparationFailed

        coordinator.start(with: MockRestPlanFactory.defaultPlan())
        await settle()

        clock.advance(minutes: 10)
        scheduler.fire()

        XCTAssertEqual(coordinator.state, .completed)
        XCTAssertEqual(coordinator.path, [.session, .result])
    }

    /// 홈으로 돌아오면 오디오 오류 표시도 사라져야 한다.
    func testAudioErrorClearsOnReturnHome() async {
        audio.prepareError = .preparationFailed
        coordinator.start(with: MockRestPlanFactory.defaultPlan())
        await settle()
        XCTAssertNotNil(coordinator.audioError)

        clock.advance(minutes: 10)
        scheduler.fire()
        coordinator.returnHome()

        XCTAssertNil(coordinator.audioError)
    }

    /// 다음 쉼을 시작하면 이전 오디오 오류가 남아 있으면 안 된다.
    func testAudioErrorResetsOnNextRest() async {
        audio.prepareError = .preparationFailed
        coordinator.start(with: MockRestPlanFactory.defaultPlan())
        await settle()
        clock.advance(minutes: 10)
        scheduler.fire()
        coordinator.returnHome()

        audio.prepareError = nil
        coordinator.start(with: MockRestPlanFactory.defaultPlan())
        await settle()

        XCTAssertNil(coordinator.audioError)
        XCTAssertTrue(audio.isPlaying)
    }
}
