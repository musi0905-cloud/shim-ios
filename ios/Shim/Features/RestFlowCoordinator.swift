//
//  RestFlowCoordinator.swift
//  Shim
//
//  Home → RestSession → RestResult → Home 흐름과 세션 상태의 단일 소스.
//
//  운영규칙 §6 — "상태는 단일 소스에서 관리"
//  docs/IOS_SPEC.md §9 — "상태 전이는 한 곳에서 관리한다."
//
//  Sprint 1 범위:
//    화면 흐름과 상태 전이만 담당한다. 오디오·타이머·밝기·알림은 붙이지 않는다.
//    이후 Sprint 에서 RestPlanExecutor 가 Service 들을 호출하게 되면
//    이 타입은 Executor 를 호출하고 상태만 반영하는 역할로 남는다.
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
            // Sprint 1 에는 준비할 시스템 자원이 없다. 바로 running 으로 간다.
            // Sprint 6 에서 RestPlanExecutor.start(plan) 이 이 자리에 들어간다.
            state = .running
            path = [.session]
        } catch {
            state = .failed
            activePlan = nil
            errorMessage = Self.message(for: error)
        }
    }

    /// 쉼을 정상 종료한다.
    func finish() {
        guard state == .running else { return }
        state = .finishing
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
        state = .idle
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
