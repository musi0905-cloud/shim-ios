//
//  RestResultView.swift
//  Shim
//
//  docs/IOS_SPEC.md §8.3
//    질문은 한 번만 한다 — "조금 나아졌나요?"
//    선택 후 즉시 홈으로 복귀한다.
//
//  Sprint 7 범위:
//    선택한 응답이 RestHistoryStore 에 저장된다.
//    통계 화면이나 기록 조회 UI 는 만들지 않는다 — 제품 철학상 대시보드를
//    만들지 않는다 (docs/IOS_SPEC.md §8.1).
//
//  이 화면은 **정상 완료한 쉼에만** 나타난다.
//  사용자가 그만둔 쉼은 여기로 오지 않는다 (D-023).
//

import SwiftUI

struct RestResultView: View {
    @EnvironmentObject private var coordinator: RestFlowCoordinator

    /// 화면에 보여줄 선택지.
    ///
    /// 문구는 표현 계층에 둔다. 저장·전송되는 값은 `RestFeedback` 이다.
    /// 문구가 바뀌어도 이미 저장된 데이터의 의미는 변하지 않아야 한다.
    private struct Choice: Identifiable {
        let feedback: RestFeedback
        let label: String
        let identifier: String

        var id: String { feedback.rawValue }
    }

    private let choices: [Choice] = [
        Choice(feedback: .better, label: "조금 나아졌어요", identifier: "feedbackBetter"),
        Choice(feedback: .same,   label: "그대로예요",     identifier: "feedbackSame"),
        Choice(feedback: .worse,  label: "더 불편해요",     identifier: "feedbackWorse"),
    ]

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("조금 나아졌나요?")
                .font(.title2)
                .accessibilityIdentifier("resultHeadline")

            VStack(spacing: 12) {
                ForEach(choices) { choice in
                    Button {
                        // 저장하고 즉시 홈으로 돌아간다.
                        coordinator.submitFeedback(choice.feedback)
                    } label: {
                        Text(choice.label)
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier(choice.identifier)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    RestResultView()
        .environmentObject(RestFlowCoordinator.previewCompleted())
}
