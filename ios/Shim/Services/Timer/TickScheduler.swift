//
//  TickScheduler.swift
//  Shim
//
//  화면 갱신용 주기 신호.
//
//  ⚠️ tick 은 **UI 를 다시 그리라는 신호일 뿐**이다.
//     남은 시간의 source of truth 가 아니다. tick 횟수를 세어 남은 시간을
//     계산하지 않는다. 남은 시간은 언제나 endsAt 과 현재 시각의 차이다.
//     (RestTimerService 참고)
//
//  tick 이 몇 번 빠지든, 앱이 background 에서 suspend 되어 아예 돌지 않든
//  남은 시간은 틀어지지 않는다. 그래서 tick 을 놓치는 것을 걱정하지 않는다.
//

import Foundation

@MainActor
protocol TickScheduler: AnyObject {
    /// 주기적으로 `onTick` 을 호출하기 시작한다. 이미 돌고 있으면 교체한다.
    func start(interval: TimeInterval, onTick: @escaping () -> Void)
    /// 신호를 멈춘다. 여러 번 호출해도 안전하다.
    func stop()
}

/// Swift Concurrency 기반 기본 구현.
///
/// 앱이 background 로 가면 이 Task 는 자연스럽게 실행되지 않는다.
/// iOS 가 앱을 suspend 하기 때문이다. **의도된 동작이다.**
/// background 에서 매초 실행을 보장하려 하지 않는다. foreground 복귀 시
/// `RestTimerService.refresh()` 가 endsAt 기준으로 다시 계산한다.
@MainActor
final class DisplayTickScheduler: TickScheduler {
    private var task: Task<Void, Never>?

    func start(interval: TimeInterval, onTick: @escaping () -> Void) {
        stop()
        let nanoseconds = UInt64(max(interval, 0.05) * 1_000_000_000)
        task = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: nanoseconds)
                if Task.isCancelled { return }
                onTick()
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    deinit {
        task?.cancel()
    }
}
