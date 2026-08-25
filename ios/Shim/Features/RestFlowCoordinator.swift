//
//  RestFlowCoordinator.swift
//  Shim
//
//  Home → RestSession → RestResult → Home 흐름과 세션 상태의 단일 소스.
//
//  운영규칙 §6 — "상태는 단일 소스에서 관리"
//  docs/IOS_SPEC.md §9 — "상태 전이는 한 곳에서 관리한다."
//
//  현재 범위 (Sprint 7):
//    화면 흐름, 상태 전이, RestTimerService, AudioService,
//    그리고 쉼 기록 저장을 담당한다. 밝기·알림은 아직 붙이지 않는다.
//    Sprint 6 에서 RestPlanExecutor 가 Service 들을 묶으면 이 타입은
//    Executor 를 호출하고 상태만 반영하는 역할로 남는다.
//
//  의존 방향:
//      RestSessionView → RestFlowCoordinator → RestTimerService
//                                            → AudioService → AVFoundation
//                                            → RestHistoryStore
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

    /// 오디오가 실패했을 때의 사용자 표시 문구. 없으면 `nil`.
    ///
    /// ⚠️ 오디오 실패는 **쉼을 중단시키지 않는다.** 타이머는 계속 돈다.
    ///    소리가 없어도 "10분 동안 화면에서 벗어난다" 는 핵심 경험은 성립한다.
    ///    오디오 실패 시 쉼 전체를 중단할지 여부는 아직 정해지지 않았다.
    ///    자동으로 결정하지 않고 이 상태로 드러내기만 한다 — D-019.
    @Published private(set) var audioError: String?

    // MARK: - 의존성

    private let timer: RestTimerService
    private let audio: AudioService
    private let history: RestHistoryStore
    private let clock: Clock
    private var audioTask: Task<Void, Never>?

    /// 이번 세션이 시작된 시각. 실제 지속시간 계산에 쓴다.
    private var sessionStartedAt: Date?

    /// 결과 화면에서 응답을 기다리는 기록.
    ///
    /// 세션이 끝날 때 만들어 두고, 응답이 정해지면 한 번만 저장한다.
    /// 저장 후 수정하는 경로를 두지 않기 위한 장치다.
    private var pendingEntry: RestHistoryEntry?

    init(
        timer: RestTimerService? = nil,
        audio: AudioService? = nil,
        history: RestHistoryStore? = nil,
        clock: Clock = SystemClock()
    ) {
        self.timer = timer ?? DefaultRestTimerService()
        self.audio = audio ?? DefaultAudioService()
        self.history = history ?? UserDefaultsRestHistoryStore()
        self.clock = clock
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
        audioError = nil
        finishReason = nil

        do {
            let validated = try RestPlanValidator.validate(plan)
            activePlan = validated
            // Sprint 6 에서 RestPlanExecutor.start(plan) 이 이 자리에 들어가
            // 오디오·밝기·알림까지 함께 시작한다. 지금은 타이머만 붙인다.
            state = .running
            sessionStartedAt = clock.now
            timer.start(duration: TimeInterval(validated.durationSeconds))
            startAudio(mode: validated.plan.audio)
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
        stopAudio()
        finishReason = .completed
        state = .completed

        let entry = makeEntry(outcome: .completed)

        if activePlan?.plan.endCheckin == true {
            // 응답을 물은 뒤 한 번만 저장한다.
            pendingEntry = entry
            path = [.session, .result]
        } else {
            // 묻지 않기로 한 계획이다. 응답 없이 바로 저장하고 홈으로 보낸다.
            // 제품 원칙 — "쉼이 끝나면 사용자를 현실로 돌려보낸다." (PRODUCT.md §1)
            history.save(entry)
            returnHome()
        }
    }

    /// 쉼을 중간에 취소한다.
    ///
    /// docs/IOS_SPEC.md §6 — cancel 은 finish(reason: cancelled) 와 같은
    /// 정리 규칙을 따른다. 타이머와 오디오를 모두 정리한다.
    ///
    /// **결과 화면으로 보내지 않는다.** 그만두겠다고 한 사람에게
    /// "조금 나아졌나요?" 를 묻는 것은 어색하다 (D-023).
    /// 기록은 `cancelled` 로 즉시 남기고 홈으로 돌아간다.
    func cancel() {
        guard state == .running else { return }
        state = .finishing
        // 취소는 정상 완료와 다르다. 타이머의 onFinish 는 발생하지 않는다.
        timer.cancel()
        stopAudio()
        finishReason = .cancelled
        state = .cancelled

        history.save(makeEntry(outcome: .cancelled))
        returnHome()
    }

    /// 결과 화면에서 사용자가 응답을 골랐다.
    ///
    /// docs/IOS_SPEC.md §8.3 — "선택 후 즉시 홈으로 복귀한다."
    func submitFeedback(_ feedback: RestFeedback) {
        pendingEntry = pendingEntry?.withFeedback(feedback)
        returnHome()
    }

    /// 결과 화면에서 홈으로 돌아온다.
    ///
    /// docs/IOS_SPEC.md §8.3 — "선택 후 즉시 홈으로 복귀한다."
    func returnHome() {
        // 응답 없이 화면을 벗어나도 기록은 남긴다.
        // 사용자가 결과 화면을 그냥 빠져나가면 feedback 은 nil 이다.
        if let entry = pendingEntry {
            history.save(entry)
            pendingEntry = nil
        }

        path = []
        activePlan = nil
        finishReason = nil
        remainingSeconds = 0
        audioError = nil
        sessionStartedAt = nil
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
        audioError = nil
        if state == .failed {
            state = .idle
        }
    }

    // MARK: - 오디오

    /// 쉼 시작과 함께 오디오를 튼다.
    ///
    /// 실패해도 쉼은 계속된다. 오류는 `audioError` 로만 드러낸다 (D-019).
    private func startAudio(mode: AudioMode) {
        audioTask?.cancel()
        audioTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.audio.prepare(mode: mode)
                guard !Task.isCancelled else { return }
                try await self.audio.play()
            } catch {
                guard !Task.isCancelled else { return }
                self.audioError = Self.audioMessage(for: error)
            }
        }
    }

    /// 오디오를 멈추고 정리한다.
    ///
    /// 정상 종료든 사용자 취소든 반드시 지나간다.
    /// 아직 시작 중인 준비 작업도 취소해, 멈춘 뒤에 뒤늦게 소리가 나지 않게 한다.
    private func stopAudio() {
        audioTask?.cancel()
        audioTask = nil
        audio.stop()
    }

    private static func audioMessage(for error: Error) -> String {
        if let audioError = error as? AudioServiceError {
            return audioError.description
        }
        return "오디오를 재생하지 못했습니다."
    }

    // MARK: - 내부

    /// 이번 세션의 기록을 만든다.
    ///
    /// 실제 지속시간은 `startedAt` 과 지금 시각의 차이에서 계산되며
    /// 음수가 되지 않는다 (`RestHistoryEntry.elapsedSeconds`).
    private func makeEntry(outcome: RestHistoryEntry.Outcome) -> RestHistoryEntry {
        let plan = activePlan?.plan
        let startedAt = sessionStartedAt ?? clock.now

        return RestHistoryEntry(
            planID: plan?.id ?? "",
            startedAt: startedAt,
            endedAt: clock.now,
            plannedDurationMinutes: plan?.durationMinutes ?? 0,
            restType: plan?.restType ?? .environmentReset,
            audio: plan?.audio ?? .silence,
            movement: plan?.movement ?? .none,
            outcome: outcome
        )
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
