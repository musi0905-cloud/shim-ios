//
//  RestFlowCoordinator.swift
//  Shim
//
//  Home → RestSession → RestResult → Home 흐름과 세션 상태의 단일 소스.
//
//  운영규칙 §6 — "상태는 단일 소스에서 관리"
//  docs/IOS_SPEC.md §9 — "상태 전이는 한 곳에서 관리한다."
//
//  현재 범위 (Sprint 2):
//    화면 흐름, 상태 전이, 그리고 RestTimerService 연결까지 담당한다.
//    오디오·밝기·알림은 아직 붙이지 않는다.
//    Sprint 6 에서 RestPlanExecutor 가 Service 들을 묶으면 이 타입은
//    Executor 를 호출하고 상태만 반영하는 역할로 남는다.
//
//  의존 방향:
//      RestSessionView → RestFlowCoordinator → RestTimerService
//
//  이 타입은 SwiftUI 외의 iOS 시스템 프레임워크를 import 하지 않는다.
//  덕분에 Simulator 에서 유닛 테스트로 흐름 전체를 검증할 수 있다.
//

import Foundation

@MainActor
final class RestFlowCoordinator: ObservableObject {

    /// 네비게이션 경로의 한 단계.
    enum Route: Hashable {
        case session
        case result
    }

    /// 쉼이 끝난 이유. 결과 화면의 문구를 고르는 데 쓴다.
    enum FinishReason: Equatable {
        case completed
        case cancelled
    }

    // MARK: - 상태 (외부에서는 읽기만 가능하다)

    @Published private(set) var path: [Route] = []
    @Published private(set) var state: RestSessionState = .idle
    @Published private(set) var activePlan: ValidatedRestPlan?
    @Published private(set) var finishReason: FinishReason?

    /// 마지막으로 발생한 오류의 사용자 표시 문구. 없으면 `nil`.
    @Published private(set) var errorMessage: String?

    /// 남은 시간(초). 화면 표시용이다.
    ///
    /// 이 값은 `RestTimerService` 가 `endsAt` 기준으로 계산해 밀어준다.
    /// tick 횟수를 누적한 값이 아니다.
    @Published private(set) var remainingSeconds: TimeInterval = 0

    // MARK: - 의존성

    private let timer: RestTimerService

    init(timer: RestTimerService? = nil) {
        self.timer = timer ?? DefaultRestTimerService()
        bindTimer()
    }

    private func bindTimer() {
        timer.onTick = { [weak self] remaining in
            self?.remainingSeconds = remaining
        }
        // 시간이 다 되면 자동 종료된다. 사용자가 아무것도 하지 않아도 된다.
        timer.onFinish = { [weak self] in
            self?.finish()
        }
    }

    // MARK: - 흐름

    /// 쉼을 시작한다.
    ///
    /// RestPlan 을 검증한 뒤에만 세션으로 진입한다.
    /// 검증에 실패하면 화면을 옮기지 않고 오류 문구만 남긴다.
    ///
    /// 이미 진행 중이면 아무 일도 하지 않는다. 중복 start 를 막는 지점이다.
    /// (docs/IOS_SPEC.md §9)
    func start(with plan: RestPlan) {
        guard state.canStart else { return }

        state = .preparing
        errorMessage = nil
        finishReason = nil

        do {
            let validated = try RestPlanValidator.validate(plan)
            activePlan = validated
            // Sprint 6 에서 RestPlanExecutor.start(plan) 이 이 자리에 들어가
            // 오디오·밝기·알림까지 함께 시작한다. 지금은 타이머만 붙인다.
            state = .running
            timer.start(duration: TimeInterval(validated.durationSeconds))
            path = [.session]
        } catch {
            state = .failed
            activePlan = nil
            errorMessage = Self.message(for: error)
        }
    }

    /// 쉼을 정상 종료한다.
    ///
    /// **시간이 다 되었을 때 `RestTimerService` 만 호출한다.**
    /// `private` 인 것은 의도적이다. 사용자가 "다 쉬었다"고 눌러 끝내는 경로를
    /// 타입 수준에서 없앤다. 사용자가 쓸 수 있는 출구는 `cancel()` 하나뿐이다.
    ///
    ///     Start → Running → Automatic Finish   ← 이 메서드
    ///     Start → Running → User Cancel        ← cancel()
    private func finish() {
        guard state == .running else { return }
        state = .finishing
        timer.cancel()
        finishReason = .completed
        state = .completed
        routeAfterFinish()
    }

    /// 쉼을 중간에 취소한다.
    ///
    /// docs/IOS_SPEC.md §6 — cancel 은 finish(reason: cancelled) 와 같은
    /// 정리 규칙을 따른다. Sprint 1 에는 정리할 자원이 없으므로 상태만 바꾼다.
    func cancel() {
        guard state == .running else { return }
        state = .finishing
        // 취소는 정상 완료와 다르다. 타이머의 onFinish 는 발생하지 않는다.
        timer.cancel()
        finishReason = .cancelled
        state = .cancelled
        routeAfterFinish()
    }

    /// 결과 화면에서 홈으로 돌아온다.
    ///
    /// docs/IOS_SPEC.md §8.3 — "선택 후 즉시 홈으로 복귀한다."
    func returnHome() {
        path = []
        activePlan = nil
        finishReason = nil
        remainingSeconds = 0
        state = .idle
    }

    // MARK: - 앱 lifecycle

    /// 앱이 foreground 로 돌아왔을 때 호출한다.
    ///
    /// background 에서는 tick 이 돌지 않는다. iOS 가 앱을 suspend 하기 때문이다.
    /// 복귀 시 `endsAt` 기준으로 남은 시간을 다시 계산한다.
    /// 이미 종료 시각이 지났다면 그 자리에서 종료 처리된다.
    ///
    /// 뷰는 `scenePhase` 변화를 이 메서드로 전달하기만 한다.
    /// 시간 계산은 전부 `RestTimerService` 가 한다.
    func handleReturnToForeground() {
        guard state == .running else { return }
        timer.refresh()
    }

    /// 오류 문구를 지운다.
    func clearError() {
        errorMessage = nil
        if state == .failed {
            state = .idle
        }
    }

    // MARK: - 내부

    /// 종료 후 결과 화면으로 갈지, 바로 홈으로 갈지 결정한다.
    ///
    /// `endCheckin` 이 false 면 사용자를 붙잡지 않고 곧장 홈으로 보낸다.
    /// 제품 원칙 — "쉼이 끝나면 사용자를 현실로 돌려보낸다." (PRODUCT.md §1)
    private func routeAfterFinish() {
        if activePlan?.plan.endCheckin == true {
            path = [.session, .result]
        } else {
            returnHome()
        }
    }

    private static func message(for error: Error) -> String {
        if let validationError = error as? RestPlanValidationError {
            return validationError.description
        }
        return "쉼을 시작할 수 없습니다."
    }
}

#if DEBUG
extension RestFlowCoordinator {
    /// SwiftUI Preview 전용 — 쉼이 진행 중인 상태의 coordinator.
    static func previewRunning() -> RestFlowCoordinator {
        let coordinator = RestFlowCoordinator()
        coordinator.start(with: MockRestPlanFactory.defaultPlan())
        return coordinator
    }

    /// SwiftUI Preview 전용 — 쉼이 정상 종료된 상태의 coordinator.
    static func previewCompleted() -> RestFlowCoordinator {
        let coordinator = previewRunning()
        coordinator.finish()
        return coordinator
    }
}
#endif
