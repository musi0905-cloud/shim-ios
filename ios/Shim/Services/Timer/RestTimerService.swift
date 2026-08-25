//
//  RestTimerService.swift
//  Shim
//
//  쉼 타이머. docs/IOS_SPEC.md §7.1
//
//  ── 핵심 규칙 ────────────────────────────────────────────────────────
//
//  남은 시간을 tick 누적으로 계산하지 않는다.
//
//      startedAt + duration = endsAt
//      remaining = max(0, endsAt - now)
//
//  tick 은 화면을 다시 그리라는 신호일 뿐이다. tick 이 몇 번 빠지든
//  남은 시간은 틀어지지 않는다.
//
//  ── background 에 대한 입장 ──────────────────────────────────────────
//
//  background 에서 매초 코드를 돌리려 하지 않는다. iOS 가 앱을 suspend 할 수
//  있고, 그것을 보장할 수도 없으며 그럴 필요도 없다.
//
//      10:00  시작, endsAt = 10:10
//      10:03  background → iOS 가 suspend. tick 안 돎.
//      10:08  foreground 복귀 → refresh()
//             remaining = 10:10 - 10:08 = 2분
//
//      10:14 에 돌아왔다면
//             remaining = max(0, 10:10 - 10:14) = 0 → 즉시 종료
//
//  ── Pause 가 없는 이유 ───────────────────────────────────────────────
//
//  제품 철학상 사용자가 쉼 시간을 관리하게 하지 않는다. "10분 동안 맡긴다"에
//  가깝다. 허용되는 흐름은 두 가지뿐이다.
//
//      Start → Running → Automatic Finish
//      Start → Running → User Cancel
//
//  ── 의존 방향 ────────────────────────────────────────────────────────
//
//      RestSessionView → RestFlowCoordinator → RestTimerService
//
//  이 파일은 UI 를 알지 못한다. SwiftUI·UIKit 을 import 하지 않는다.
//

import Foundation

@MainActor
protocol RestTimerService: AnyObject {
    /// 남은 시간(초). 항상 0 이상이다. 돌고 있지 않으면 0.
    var remaining: TimeInterval { get }

    /// 타이머가 진행 중인지. 종료·취소 후에는 false.
    var isRunning: Bool { get }

    /// 화면 갱신 신호. 남은 시간을 전달한다.
    var onTick: ((TimeInterval) -> Void)? { get set }

    /// 시간이 다 되었을 때 **정확히 한 번** 호출된다.
    /// 사용자가 취소한 경우에는 호출되지 않는다.
    var onFinish: (() -> Void)? { get set }

    /// 타이머를 시작한다. 이미 진행 중이면 무시한다.
    func start(duration: TimeInterval)

    /// 사용자 취소. `onFinish` 는 호출되지 않는다.
    func cancel()

    /// 남은 시간을 지금 시각 기준으로 다시 계산한다.
    ///
    /// foreground 복귀 시 호출한다. 이미 종료 시각이 지났으면 즉시 종료 처리한다.
    @discardableResult
    func refresh() -> TimeInterval
}

@MainActor
final class DefaultRestTimerService: RestTimerService {

    private let clock: Clock
    private let scheduler: TickScheduler

    /// 목표 종료 시각. 이 값 하나가 남은 시간의 source of truth 다.
    private(set) var endsAt: Date?
    /// 이 세션에서 완료 콜백을 이미 보냈는지. 중복 발화를 막는다.
    private var hasFinished = false

    var onTick: ((TimeInterval) -> Void)?
    var onFinish: (() -> Void)?

    init(clock: Clock = SystemClock(),
         scheduler: TickScheduler? = nil) {
        self.clock = clock
        self.scheduler = scheduler ?? DisplayTickScheduler()
    }

    // MARK: - 상태

    var remaining: TimeInterval {
        guard let endsAt else { return 0 }
        return max(0, endsAt.timeIntervalSince(clock.now))
    }

    var isRunning: Bool {
        endsAt != nil && !hasFinished
    }

    // MARK: - 흐름

    func start(duration: TimeInterval) {
        // 중복 start 방지. 두 개의 타이머가 동시에 돌지 않는다.
        guard !isRunning else { return }

        // duration 은 RestPlanValidator 가 이미 1~60분으로 걸렀다.
        // 그래도 0 이하가 들어오면 시작하지 않는다. 즉시 종료 콜백을 쏘면
        // 호출부가 start 안에서 finish 를 받는 예상 못한 순서가 된다.
        guard duration > 0 else { return }

        hasFinished = false
        endsAt = clock.now.addingTimeInterval(duration)

        onTick?(remaining)

        scheduler.start(interval: 1.0) { [weak self] in
            self?.refresh()
        }
    }

    func cancel() {
        scheduler.stop()
        // endsAt 을 지우면 이후 refresh 가 종료 처리를 하지 않는다.
        // 사용자가 취소한 쉼에서 완료 콜백이 뒤늦게 오면 안 된다.
        endsAt = nil
        hasFinished = false
        onTick?(0)
    }

    @discardableResult
    func refresh() -> TimeInterval {
        // 취소됐거나 시작 전이면 할 일이 없다.
        guard endsAt != nil else { return 0 }
        // 이미 완료를 보냈으면 다시 보내지 않는다.
        guard !hasFinished else { return 0 }

        let value = remaining
        onTick?(value)

        if value <= 0 {
            complete()
        }
        return value
    }

    // MARK: - 내부

    /// 완료 콜백을 정확히 한 번만 보낸다.
    private func complete() {
        guard !hasFinished else { return }
        hasFinished = true
        scheduler.stop()
        onFinish?()
    }
}
