//
//  RestFlowTimerIntegrationTests.swift
//  ShimTests
//
//  Coordinator 와 TimerService 가 이어져 동작하는지 확인한다.
//
//  허용되는 흐름은 두 가지뿐이다.
//      Start → Running → Automatic Finish
//      Start → Running → User Cancel
//
//  Pause / Resume 은 없다.
//

import XCTest
@testable import Shim

@MainActor
final class RestFlowTimerIntegrationTests: XCTestCase {

    private var clock: MutableClock!
    private var scheduler: ManualTickScheduler!
    private var history: InMemoryRestHistoryStore!
    private var coordinator: RestFlowCoordinator!

    override func setUp() async throws {
        try await super.setUp()
        clock = MutableClock()
        scheduler = ManualTickScheduler()
        history = InMemoryRestHistoryStore()
        coordinator = RestFlowCoordinator(
            timer: DefaultRestTimerService(clock: clock, scheduler: scheduler),
            audio: SpyAudioService(),
            history: history,
            clock: clock
        )
    }

    override func tearDown() async throws {
        coordinator = nil
        history = nil
        scheduler = nil
        clock = nil
        try await super.tearDown()
    }

    // MARK: - Start → Running → Automatic Finish

    /// 사용자가 아무것도 하지 않아도 시간이 다 되면 결과 화면으로 간다.
    func testTimerExpiryFinishesRestAutomatically() {
        coordinator.start(with: MockRestPlanFactory.defaultPlan())

        XCTAssertEqual(coordinator.state, .running)
        XCTAssertEqual(coordinator.remainingSeconds, 600, accuracy: 0.001)
        XCTAssertEqual(coordinator.path, [.session])

        clock.advance(minutes: 10)
        scheduler.fire()

        XCTAssertEqual(coordinator.state, .completed)
        XCTAssertEqual(coordinator.finishReason, .completed)
        XCTAssertEqual(coordinator.path, [.session, .result])
    }

    /// 진행 중에는 남은 시간이 화면으로 밀려와야 한다.
    func testRemainingSecondsIsPublishedWhileRunning() {
        coordinator.start(with: MockRestPlanFactory.defaultPlan())

        clock.advance(minutes: 3)
        scheduler.fire()
        XCTAssertEqual(coordinator.remainingSeconds, 420, accuracy: 0.001)

        clock.advance(minutes: 6)
        scheduler.fire()
        XCTAssertEqual(coordinator.remainingSeconds, 60, accuracy: 0.001)
        XCTAssertEqual(coordinator.state, .running, "아직 끝나지 않았다")
    }

    // MARK: - Start → Running → User Cancel

    /// 사용자가 그만두면 완료가 아니라 취소로 기록되어야 한다.
    ///
    /// 취소 후에는 곧바로 홈으로 돌아가므로 `state` 는 `.idle` 이다.
    /// 취소였다는 사실은 저장된 기록이 증명한다 (D-023).
    func testUserCancelIsDistinctFromCompletion() {
        coordinator.start(with: MockRestPlanFactory.defaultPlan())

        clock.advance(minutes: 2)
        coordinator.cancel()

        XCTAssertEqual(history.entries.first?.outcome, .cancelled)
        XCTAssertNotEqual(history.entries.first?.outcome, .completed)
        XCTAssertEqual(coordinator.state, .idle, "취소 후 즉시 홈으로 돌아간다")
    }

    /// 취소한 뒤 원래 종료 시각이 지나도 완료 기록이 생기면 안 된다.
    func testCancelledRestDoesNotCompleteLater() {
        coordinator.start(with: MockRestPlanFactory.defaultPlan())
        coordinator.cancel()

        clock.advance(minutes: 30)
        scheduler.fire(times: 5)
        coordinator.handleReturnToForeground()

        XCTAssertEqual(history.entries.count, 1, "기록이 하나뿐이어야 한다")
        XCTAssertEqual(history.entries.first?.outcome, .cancelled)
        XCTAssertEqual(coordinator.state, .idle)
    }

    // MARK: - background 왕복

    /// background 에 다녀와도 남은 시간이 맞아야 한다.
    func testReturningFromBackgroundRecalculatesRemaining() {
        coordinator.start(with: MockRestPlanFactory.defaultPlan())

        clock.advance(minutes: 3)
        scheduler.fire()

        // background — tick 없음
        clock.advance(minutes: 5)

        coordinator.handleReturnToForeground()

        XCTAssertEqual(coordinator.remainingSeconds, 120, accuracy: 0.001)
        XCTAssertEqual(coordinator.state, .running)
    }

    /// background 에 있는 동안 시간이 다 지났으면 복귀 즉시 결과 화면으로 가야 한다.
    func testReturningAfterEndGoesStraightToResult() {
        coordinator.start(with: MockRestPlanFactory.defaultPlan())

        clock.advance(minutes: 14)
        coordinator.handleReturnToForeground()

        XCTAssertEqual(coordinator.state, .completed)
        XCTAssertEqual(coordinator.remainingSeconds, 0)
        XCTAssertEqual(coordinator.path, [.session, .result])
    }

    /// 쉼이 돌고 있지 않을 때 foreground 복귀는 아무 일도 하지 않아야 한다.
    func testForegroundReturnIsNoOpWhenIdle() {
        coordinator.handleReturnToForeground()

        XCTAssertEqual(coordinator.state, .idle)
        XCTAssertTrue(coordinator.path.isEmpty)
    }

    // MARK: - 중복 방지 · 재사용

    /// 중복 start 로 두 번째 계획이 타이머를 덮어쓰면 안 된다.
    func testDuplicateStartDoesNotRestartTimer() {
        coordinator.start(with: MockRestPlanFactory.defaultPlan())
        clock.advance(minutes: 2)

        coordinator.start(with: MockRestPlanFactory.shortPlan(minutes: 1))

        XCTAssertEqual(scheduler.startCount, 1)
        coordinator.handleReturnToForeground()
        XCTAssertEqual(coordinator.remainingSeconds, 480, accuracy: 0.001,
                       "첫 계획의 종료 시각이 유지되어야 한다")
    }

    /// 홈으로 돌아온 뒤 새 쉼을 시작할 수 있어야 한다.
    func testCanRunAnotherRestAfterReturningHome() {
        coordinator.start(with: MockRestPlanFactory.defaultPlan())
        clock.advance(minutes: 10)
        scheduler.fire()
        coordinator.returnHome()

        XCTAssertEqual(coordinator.remainingSeconds, 0)

        coordinator.start(with: MockRestPlanFactory.shortPlan(minutes: 5))

        XCTAssertEqual(coordinator.state, .running)
        XCTAssertEqual(coordinator.remainingSeconds, 300, accuracy: 0.001)

        clock.advance(minutes: 5)
        scheduler.fire()
        XCTAssertEqual(coordinator.state, .completed)
    }

    /// 검증에 실패하면 타이머가 시작되지 않아야 한다.
    func testInvalidPlanNeverStartsTimer() {
        let invalid = RestPlan(
            durationMinutes: 0,
            restType: .environmentReset,
            audio: .silence,
            movement: .none,
            screenMode: .minimal
        )

        coordinator.start(with: invalid)

        XCTAssertEqual(scheduler.startCount, 0, "검증 실패 시 타이머는 돌지 않는다")
        XCTAssertEqual(coordinator.state, .failed)
    }
}
