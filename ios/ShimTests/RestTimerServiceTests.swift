//
//  RestTimerServiceTests.swift
//  ShimTests
//
//  docs/IOS_SPEC.md §7.1 의 규칙을 테스트로 고정한다.
//
//    - 남은 시간은 tick 누적이 아니라 endsAt 과 현재 시각의 차이다
//    - background 왕복에도 어긋나지 않는다
//    - 완료 콜백은 정확히 한 번
//    - 중복 start 로 두 개의 타이머가 돌지 않는다
//    - 취소 후에는 완료 콜백이 오지 않는다
//

import XCTest
@testable import Shim

@MainActor
final class RestTimerServiceTests: XCTestCase {

    private var clock: MutableClock!
    private var scheduler: ManualTickScheduler!
    private var service: DefaultRestTimerService!

    private var finishCount = 0
    private var tickedValues: [TimeInterval] = []

    private let tenMinutes: TimeInterval = 600

    override func setUp() async throws {
        try await super.setUp()
        clock = MutableClock()
        scheduler = ManualTickScheduler()
        service = DefaultRestTimerService(clock: clock, scheduler: scheduler)
        finishCount = 0
        tickedValues = []
        service.onFinish = { [weak self] in self?.finishCount += 1 }
        service.onTick = { [weak self] value in self?.tickedValues.append(value) }
    }

    override func tearDown() async throws {
        service = nil
        scheduler = nil
        clock = nil
        try await super.tearDown()
    }

    // MARK: - 시작

    /// 10분으로 시작하면 남은 시간이 600초여야 한다.
    func testTenMinutePlanStartsAtSixHundredSeconds() {
        service.start(duration: tenMinutes)

        XCTAssertEqual(service.remaining, 600, accuracy: 0.001)
        XCTAssertTrue(service.isRunning)
        XCTAssertEqual(tickedValues.first, 600, "시작 즉시 첫 값을 밀어줘야 한다")
    }

    func testStartSchedulesTicks() {
        service.start(duration: tenMinutes)

        XCTAssertEqual(scheduler.startCount, 1)
        XCTAssertTrue(scheduler.isRunning)
        XCTAssertEqual(scheduler.lastInterval, 1.0)
    }

    func testDoesNotStartWithNonPositiveDuration() {
        service.start(duration: 0)
        XCTAssertFalse(service.isRunning)
        XCTAssertEqual(scheduler.startCount, 0)
        XCTAssertEqual(finishCount, 0, "0초로는 시작도 완료도 하지 않는다")
    }

    // MARK: - 시간 경과

    /// 남은 시간은 경과한 실제 시간을 정확히 반영해야 한다.
    func testRemainingReflectsElapsedTime() {
        service.start(duration: tenMinutes)

        clock.advance(minutes: 1)
        XCTAssertEqual(service.remaining, 540, accuracy: 0.001)

        clock.advance(minutes: 4)
        XCTAssertEqual(service.remaining, 300, accuracy: 0.001)

        clock.advance(by: 299)
        XCTAssertEqual(service.remaining, 1, accuracy: 0.001, "종료 직전")
    }

    /// tick 횟수는 남은 시간과 무관하다.
    ///
    /// tick 이 100번 와도 시계가 안 갔으면 남은 시간은 그대로여야 한다.
    /// tick 누적 방식이었다면 이 테스트가 깨진다.
    func testTickCountDoesNotAffectRemaining() {
        service.start(duration: tenMinutes)

        scheduler.fire(times: 100)

        XCTAssertEqual(service.remaining, 600, accuracy: 0.001,
                       "tick 은 화면 갱신 신호일 뿐 시간의 근거가 아니다")
        XCTAssertEqual(finishCount, 0)
    }

    /// 반대로 tick 이 하나도 오지 않아도 남은 시간은 정확해야 한다.
    func testRemainingIsCorrectWithoutAnyTick() {
        service.start(duration: tenMinutes)

        clock.advance(minutes: 7)

        XCTAssertEqual(service.remaining, 180, accuracy: 0.001)
    }

    // MARK: - 종료

    /// 종료 시각을 지나도 음수가 되지 않아야 한다.
    func testRemainingNeverGoesBelowZero() {
        service.start(duration: tenMinutes)

        clock.advance(minutes: 30)

        XCTAssertEqual(service.remaining, 0, "0 미만으로 내려가지 않는다")
    }

    func testFinishesExactlyAtEndTime() {
        service.start(duration: tenMinutes)

        clock.advance(by: 600)
        service.refresh()

        XCTAssertEqual(finishCount, 1)
        XCTAssertEqual(service.remaining, 0)
        XCTAssertFalse(service.isRunning)
    }

    /// 완료 콜백은 정확히 한 번만 발생해야 한다.
    func testFinishFiresOnlyOnce() {
        service.start(duration: tenMinutes)

        clock.advance(minutes: 11)

        service.refresh()
        service.refresh()
        service.refresh()
        scheduler.fire(times: 5)

        XCTAssertEqual(finishCount, 1, "여러 번 확인해도 완료는 한 번이다")
    }

    func testStopsTickingAfterFinish() {
        service.start(duration: tenMinutes)
        clock.advance(minutes: 11)
        service.refresh()

        XCTAssertFalse(scheduler.isRunning, "끝났으면 tick 도 멈춘다")
    }

    // MARK: - background 왕복

    /// background 동안 tick 이 전혀 오지 않아도 복귀 시 남은 시간이 맞아야 한다.
    ///
    ///   10:00 시작 (endsAt 10:10)
    ///   10:03 background — iOS 가 suspend, tick 없음
    ///   10:08 복귀 → 남은 시간 2분
    func testForegroundReturnRecalculatesRemaining() {
        service.start(duration: tenMinutes)

        // 3분간 정상 동작
        clock.advance(minutes: 3)
        scheduler.fire()
        XCTAssertEqual(service.remaining, 420, accuracy: 0.001)

        // background — tick 을 부르지 않는다. 시간만 흐른다.
        clock.advance(minutes: 5)

        // foreground 복귀
        let recalculated = service.refresh()

        XCTAssertEqual(recalculated, 120, accuracy: 0.001, "10:10 - 10:08 = 2분")
        XCTAssertEqual(finishCount, 0, "아직 끝나지 않았다")
        XCTAssertTrue(service.isRunning)
    }

    /// 종료 시각이 지난 뒤 복귀하면 즉시 종료되어야 한다.
    ///
    ///   10:14 복귀 → now > endsAt → remaining 0 → 즉시 finish
    func testForegroundReturnAfterEndFinishesImmediately() {
        service.start(duration: tenMinutes)

        // background 상태로 종료 시각을 훌쩍 넘긴다
        clock.advance(minutes: 14)

        let recalculated = service.refresh()

        XCTAssertEqual(recalculated, 0)
        XCTAssertEqual(finishCount, 1, "복귀 즉시 종료된다")
        XCTAssertFalse(service.isRunning)
    }

    // MARK: - 중복 start 방지

    func testDuplicateStartIsIgnored() {
        service.start(duration: tenMinutes)
        clock.advance(minutes: 2)

        // 진행 중에 다시 시작
        service.start(duration: 60)

        XCTAssertEqual(scheduler.startCount, 1, "타이머가 두 개 돌면 안 된다")
        XCTAssertEqual(service.remaining, 480, accuracy: 0.001,
                       "첫 번째 계획의 종료 시각이 유지되어야 한다")
    }

    // MARK: - 취소

    /// 취소한 뒤에는 완료 콜백이 오지 않아야 한다.
    func testNoFinishAfterCancel() {
        service.start(duration: tenMinutes)
        clock.advance(minutes: 2)

        service.cancel()

        // 취소 후 원래 종료 시각을 한참 지난다
        clock.advance(minutes: 30)
        service.refresh()
        scheduler.fire(times: 3)

        XCTAssertEqual(finishCount, 0, "취소한 쉼은 완료되지 않는다")
        XCTAssertFalse(service.isRunning)
        XCTAssertEqual(service.remaining, 0)
    }

    func testCancelStopsTicking() {
        service.start(duration: tenMinutes)
        service.cancel()

        XCTAssertFalse(scheduler.isRunning)
        XCTAssertGreaterThanOrEqual(scheduler.stopCount, 1)
    }

    // MARK: - 재사용

    /// 완료 후 새 세션을 시작할 수 있어야 한다.
    func testCanStartNewSessionAfterFinish() {
        service.start(duration: tenMinutes)
        clock.advance(minutes: 11)
        service.refresh()
        XCTAssertEqual(finishCount, 1)

        service.start(duration: 300)

        XCTAssertTrue(service.isRunning)
        XCTAssertEqual(service.remaining, 300, accuracy: 0.001)
        XCTAssertEqual(scheduler.startCount, 2)

        clock.advance(by: 300)
        service.refresh()
        XCTAssertEqual(finishCount, 2, "새 세션도 정상적으로 완료된다")
    }

    /// 취소 후 새 세션을 시작할 수 있어야 한다.
    func testCanStartNewSessionAfterCancel() {
        service.start(duration: tenMinutes)
        service.cancel()

        service.start(duration: 120)

        XCTAssertTrue(service.isRunning)
        XCTAssertEqual(service.remaining, 120, accuracy: 0.001)
    }
}
