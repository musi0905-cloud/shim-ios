//
//  RestFlowFeedbackIntegrationTests.swift
//  ShimTests
//
//  Sprint 7 — 쉼 흐름과 기록 저장이 이어져 동작하는지 확인한다.
//
//  저장 규칙 (D-023):
//
//      정상 완료 + endCheckin == true
//        → RestResult → feedback 선택 → completed + feedback 저장
//
//      정상 완료 + endCheckin == false
//        → 즉시 completed + feedback:nil 저장 → Home
//
//      사용자 취소
//        → RestResult 로 보내지 않는다
//        → 즉시 cancelled + feedback:nil 저장 → Home
//

import XCTest
@testable import Shim

@MainActor
final class RestFlowFeedbackIntegrationTests: XCTestCase {

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

    /// 10분 쉼을 끝까지 진행시킨다.
    private func completeRest() {
        coordinator.start(with: MockRestPlanFactory.defaultPlan())
        clock.advance(minutes: 10)
        scheduler.fire()
    }

    // MARK: - 정상 완료 + endCheckin == true

    func testCompletedRestGoesToResultScreenBeforeSaving() {
        completeRest()

        XCTAssertEqual(coordinator.path, [.session, .result])
        XCTAssertEqual(history.saveCallCount, 0, "응답을 받기 전에는 저장하지 않는다")
    }

    /// 세 선택지 각각이 저장되어야 한다.
    func testEachFeedbackChoiceIsSaved() {
        for expected in RestFeedback.allCases {
            let store = InMemoryRestHistoryStore()
            let localClock = MutableClock()
            let localScheduler = ManualTickScheduler()
            let flow = RestFlowCoordinator(
                timer: DefaultRestTimerService(clock: localClock, scheduler: localScheduler),
                audio: SpyAudioService(),
                history: store,
                clock: localClock
            )

            flow.start(with: MockRestPlanFactory.defaultPlan())
            localClock.advance(minutes: 10)
            localScheduler.fire()
            flow.submitFeedback(expected)

            XCTAssertEqual(store.entries.count, 1)
            XCTAssertEqual(store.entries.first?.feedback, expected)
            XCTAssertEqual(store.entries.first?.outcome, .completed)
        }
    }

    /// 선택 후 즉시 홈으로 돌아가야 한다. (docs/IOS_SPEC.md §8.3)
    func testSubmittingFeedbackReturnsHomeImmediately() {
        completeRest()

        coordinator.submitFeedback(.better)

        XCTAssertTrue(coordinator.path.isEmpty)
        XCTAssertEqual(coordinator.state, .idle)
    }

    /// 기록이 해당 RestPlan 과 연결되어야 한다. (AC-2)
    func testEntryIsLinkedToThePlan() {
        let plan = MockRestPlanFactory.defaultPlan()
        coordinator.start(with: plan)
        clock.advance(minutes: 10)
        scheduler.fire()
        coordinator.submitFeedback(.same)

        let entry = history.entries.first
        XCTAssertEqual(entry?.planID, plan.id)
        XCTAssertEqual(entry?.plannedDurationMinutes, plan.durationMinutes)
        XCTAssertEqual(entry?.restType, plan.restType)
        XCTAssertEqual(entry?.audio, plan.audio)
        XCTAssertEqual(entry?.movement, plan.movement)
    }

    func testCompletedRestRecordsFullDuration() {
        completeRest()
        coordinator.submitFeedback(.better)

        XCTAssertEqual(history.entries.first?.actualDurationSeconds, 600)
    }

    /// 응답 없이 결과 화면을 벗어나도 기록은 남아야 한다.
    func testLeavingResultWithoutChoosingStillSaves() {
        completeRest()

        coordinator.returnHome()

        XCTAssertEqual(history.entries.count, 1)
        XCTAssertNil(history.entries.first?.feedback)
        XCTAssertEqual(history.entries.first?.outcome, .completed)
    }

    /// 기록은 정확히 한 번만 저장되어야 한다.
    func testEntryIsSavedExactlyOnce() {
        completeRest()

        coordinator.submitFeedback(.better)
        coordinator.returnHome()
        coordinator.returnHome()

        XCTAssertEqual(history.saveCallCount, 1)
    }

    // MARK: - 정상 완료 + endCheckin == false

    func testEndCheckinFalseSavesImmediatelyWithoutResultScreen() {
        let plan = RestPlan(
            durationMinutes: 5,
            restType: .environmentReset,
            audio: .silence,
            movement: .none,
            screenMode: .minimal,
            endCheckin: false
        )

        coordinator.start(with: plan)
        clock.advance(minutes: 5)
        scheduler.fire()

        XCTAssertTrue(coordinator.path.isEmpty, "결과 화면을 거치지 않는다")
        XCTAssertEqual(history.entries.count, 1)
        XCTAssertEqual(history.entries.first?.outcome, .completed)
        XCTAssertNil(history.entries.first?.feedback)
        XCTAssertEqual(history.entries.first?.actualDurationSeconds, 300)
    }

    // MARK: - 사용자 취소 (D-023)

    /// 취소한 사용자를 결과 화면으로 보내지 않는다.
    func testCancelDoesNotGoToResultScreen() {
        coordinator.start(with: MockRestPlanFactory.defaultPlan())
        clock.advance(minutes: 2)

        coordinator.cancel()

        XCTAssertTrue(coordinator.path.isEmpty,
                      "그만두겠다는 사람에게 '조금 나아졌나요?' 를 묻지 않는다")
        XCTAssertEqual(coordinator.state, .idle)
    }

    func testCancelSavesCancelledEntryImmediately() {
        coordinator.start(with: MockRestPlanFactory.defaultPlan())
        clock.advance(minutes: 2)

        coordinator.cancel()

        XCTAssertEqual(history.entries.count, 1)
        XCTAssertEqual(history.entries.first?.outcome, .cancelled)
        XCTAssertNil(history.entries.first?.feedback, "묻지 않았으므로 nil 이다")
    }

    /// 계획 시간과 실제 시간이 모두 남아야 한다.
    func testCancelRecordsPlannedAndActualDuration() {
        coordinator.start(with: MockRestPlanFactory.defaultPlan())
        clock.advance(minutes: 2)
        coordinator.cancel()

        let entry = history.entries.first
        XCTAssertEqual(entry?.plannedDurationMinutes, 10, "계획은 10분")
        XCTAssertEqual(entry?.actualDurationSeconds, 120, "실제로는 2분")
    }

    /// 2분 취소와 9분 50초 취소가 구분되어야 한다.
    func testEarlyAndLateCancelsAreDistinguishable() {
        coordinator.start(with: MockRestPlanFactory.defaultPlan())
        clock.advance(minutes: 2)
        coordinator.cancel()

        coordinator.start(with: MockRestPlanFactory.defaultPlan())
        clock.advance(by: 590)
        coordinator.cancel()

        let durations = history.entries.map(\.actualDurationSeconds)
        XCTAssertEqual(Set(durations), [120, 590])
    }

    // MARK: - 실패해도 흐름이 멈추지 않는다 (Sprint 7 요구 7)

    func testSaveFailureDoesNotBreakTheFlow() {
        history.failsSilently = true

        completeRest()
        coordinator.submitFeedback(.better)

        XCTAssertEqual(coordinator.state, .idle, "저장이 실패해도 홈으로 돌아간다")
        XCTAssertTrue(coordinator.path.isEmpty)
        XCTAssertTrue(history.entries.isEmpty)
    }

    func testSaveFailureOnCancelDoesNotBreakTheFlow() {
        history.failsSilently = true

        coordinator.start(with: MockRestPlanFactory.defaultPlan())
        coordinator.cancel()

        XCTAssertEqual(coordinator.state, .idle)
        XCTAssertTrue(coordinator.path.isEmpty)
    }

    // MARK: - 시작하지 않은 쉼

    /// 검증에 실패한 계획은 기록되지 않아야 한다.
    func testInvalidPlanIsNotRecorded() {
        let invalid = RestPlan(
            durationMinutes: 0,
            restType: .environmentReset,
            audio: .silence,
            movement: .none,
            screenMode: .minimal
        )

        coordinator.start(with: invalid)

        XCTAssertEqual(history.saveCallCount, 0)
    }

    /// 여러 번의 쉼이 모두 기록되어야 한다.
    func testMultipleRestsAreAllRecorded() {
        completeRest()
        coordinator.submitFeedback(.better)

        coordinator.start(with: MockRestPlanFactory.shortPlan(minutes: 5))
        clock.advance(minutes: 1)
        coordinator.cancel()

        XCTAssertEqual(history.entries.count, 2)
        XCTAssertEqual(history.entries.first?.outcome, .cancelled, "최신이 앞")
        XCTAssertEqual(history.entries.last?.outcome, .completed)
    }
}
