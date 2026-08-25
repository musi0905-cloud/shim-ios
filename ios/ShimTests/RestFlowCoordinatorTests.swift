//
//  RestFlowCoordinatorTests.swift
//  ShimTests
//
//  Home → RestSession → RestResult → Home 흐름을 Simulator/CI 에서
//  검증 가능한 형태로 고정한다.
//
//  Coordinator 가 시스템 프레임워크에 의존하지 않기 때문에 UI 테스트 없이
//  흐름 전체를 유닛 테스트로 확인할 수 있다.
//
//  docs/IOS_SPEC.md §9 — 상태 전이는 한 곳에서 관리하고 중복 start 를 막는다.
//

import XCTest
@testable import Shim

@MainActor
final class RestFlowCoordinatorTests: XCTestCase {

    private var coordinator: RestFlowCoordinator!
    private var clock: MutableClock!
    private var scheduler: ManualTickScheduler!
    private var history: InMemoryRestHistoryStore!

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

    /// 쉼이 시간이 다 되어 자동 종료되게 한다.
    ///
    /// Sprint 2 부터 `finish()` 는 타이머만 호출한다. 사용자가 직접 부르는
    /// 경로는 없으므로 테스트도 시간을 흘려보내 종료시킨다.
    private func elapseUntilFinished() {
        clock.advance(minutes: 60)
        scheduler.fire()
    }

    // MARK: - 초기 상태

    func testStartsAtHomeInIdleState() {
        XCTAssertEqual(coordinator.state, .idle)
        XCTAssertTrue(coordinator.path.isEmpty)
        XCTAssertNil(coordinator.activePlan)
        XCTAssertNil(coordinator.errorMessage)
    }

    // MARK: - 전체 흐름

    /// Home → RestSession → RestResult → Home
    func testCompleteFlowReturnsHome() {
        coordinator.start(with: MockRestPlanFactory.defaultPlan())
        XCTAssertEqual(coordinator.state, .running)
        XCTAssertEqual(coordinator.path, [.session])
        XCTAssertNotNil(coordinator.activePlan)

        elapseUntilFinished()
        XCTAssertEqual(coordinator.state, .completed)
        XCTAssertEqual(coordinator.path, [.session, .result])
        XCTAssertEqual(coordinator.finishReason, .completed)

        coordinator.returnHome()
        XCTAssertEqual(coordinator.state, .idle)
        XCTAssertTrue(coordinator.path.isEmpty)
        XCTAssertNil(coordinator.activePlan)
    }

    /// Home → RestSession → (중단) → Home
    ///
    /// 취소한 사용자는 결과 화면을 거치지 않는다 (D-023).
    /// 그만두겠다는 사람에게 "조금 나아졌나요?" 를 묻지 않는다.
    func testCancelReturnsHomeWithoutResultScreen() {
        coordinator.start(with: MockRestPlanFactory.defaultPlan())
        coordinator.cancel()

        XCTAssertTrue(coordinator.path.isEmpty, "결과 화면을 거치지 않는다")
        XCTAssertEqual(coordinator.state, .idle)
        XCTAssertNil(coordinator.activePlan)
    }

    /// endCheckin 이 false 면 결과 화면을 거치지 않고 바로 홈으로 간다.
    /// 제품 원칙 — 쉼이 끝나면 사용자를 붙잡지 않는다.
    func testSkipsResultScreenWhenEndCheckinIsFalse() {
        let plan = RestPlan(
            durationMinutes: 5,
            restType: .environmentReset,
            audio: .silence,
            movement: .none,
            screenMode: .minimal,
            endCheckin: false
        )

        coordinator.start(with: plan)
        elapseUntilFinished()

        XCTAssertTrue(coordinator.path.isEmpty, "결과 화면을 거치지 않아야 한다")
        XCTAssertEqual(coordinator.state, .idle)
    }

    // MARK: - 중복 실행 방지

    /// running 중 다시 시작해도 두 번째 시작은 무시되어야 한다.
    /// docs/IOS_SPEC.md §9
    func testDuplicateStartIsIgnoredWhileRunning() {
        let first = MockRestPlanFactory.defaultPlan()
        coordinator.start(with: first)
        let planAfterFirstStart = coordinator.activePlan

        coordinator.start(with: MockRestPlanFactory.shortPlan(minutes: 1))

        XCTAssertEqual(coordinator.activePlan, planAfterFirstStart, "계획이 바뀌면 안 된다")
        XCTAssertEqual(coordinator.path, [.session], "화면이 중복으로 쌓이면 안 된다")
    }

    func testCanStartAgainAfterReturningHome() {
        coordinator.start(with: MockRestPlanFactory.defaultPlan())
        elapseUntilFinished()
        coordinator.returnHome()

        coordinator.start(with: MockRestPlanFactory.shortPlan(minutes: 2))

        XCTAssertEqual(coordinator.state, .running)
        XCTAssertEqual(coordinator.activePlan?.plan.durationMinutes, 2)
    }

    /// 시작하지 않았는데 취소를 호출해도 상태가 망가지지 않아야 한다.
    func testCancelIsNoOpWhenIdle() {
        coordinator.cancel()
        XCTAssertEqual(coordinator.state, .idle)
        XCTAssertTrue(coordinator.path.isEmpty)
    }

    // MARK: - 검증 실패 처리

    /// 검증에 실패한 계획으로는 세션에 진입하지 않아야 한다.
    func testInvalidPlanDoesNotEnterSession() {
        let invalid = RestPlan(
            durationMinutes: 0,
            restType: .environmentReset,
            audio: .silence,
            movement: .none,
            screenMode: .minimal
        )

        coordinator.start(with: invalid)

        XCTAssertEqual(coordinator.state, .failed)
        XCTAssertTrue(coordinator.path.isEmpty, "화면을 옮기면 안 된다")
        XCTAssertNil(coordinator.activePlan)
        XCTAssertNotNil(coordinator.errorMessage)
    }

    func testCanRecoverAfterValidationFailure() {
        let invalid = RestPlan(
            durationMinutes: 0,
            restType: .environmentReset,
            audio: .silence,
            movement: .none,
            screenMode: .minimal
        )
        coordinator.start(with: invalid)
        coordinator.clearError()

        XCTAssertNil(coordinator.errorMessage)
        XCTAssertEqual(coordinator.state, .idle)

        coordinator.start(with: MockRestPlanFactory.defaultPlan())
        XCTAssertEqual(coordinator.state, .running)
    }

    /// 검증 보정이 실행 계층으로 전달되어야 한다.
    func testValidationAdjustmentsReachTheSession() {
        let plan = RestPlan(
            durationMinutes: 10,
            restType: .environmentReset,
            audio: .calmAcoustic,
            movement: .slowWalk,
            screenMode: .minimal,
            brightness: 5.0
        )

        coordinator.start(with: plan)

        XCTAssertEqual(coordinator.activePlan?.plan.brightness, 1.0)
        XCTAssertEqual(coordinator.activePlan?.adjustments, [.brightnessClamped(from: 5.0, to: 1.0)])
    }

    // MARK: - 상태 규칙

    func testSessionStateStartRules() {
        XCTAssertTrue(RestSessionState.idle.canStart)
        XCTAssertTrue(RestSessionState.completed.canStart)
        XCTAssertTrue(RestSessionState.cancelled.canStart)
        XCTAssertTrue(RestSessionState.failed.canStart)

        XCTAssertFalse(RestSessionState.preparing.canStart)
        XCTAssertFalse(RestSessionState.running.canStart)
        XCTAssertFalse(RestSessionState.finishing.canStart)
    }
}
