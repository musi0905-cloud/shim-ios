//
//  RestResultView.swift
//  Shim
//
//  docs/IOS_SPEC.md §8.3
//    질문은 한 번만 한다 — "조금 나아졌나요?"
//    선택 후 즉시 홈으로 복귀한다.
//
//  Sprint 1 범위: 선택값을 저장하지 않는다.
//  RestFeedback 모델과 로컬 저장은 Sprint 7 이다.
//

import SwiftUI

struct RestResultView: View {
    @EnvironmentObject private var coordinator: RestFlowCoordinator

    /// 화면에 보여줄 선택지.
    ///
    /// Sprint 7 에서 저장 가능한 `RestFeedback` 모델로 승격된다.
    /// 지금은 저장하지 않으므로 화면 안에만 둔다.
    private enum Choice: String, CaseIterable, Identifiable {
        case better = "조금 나아졌어요"
        case same = "그대로예요"
        case worse = "더 불편해요"

        var id: String { rawValue }
        var identifier: String {
            switch self {
            case .better: return "feedbackBetter"
            case .same: return "feedbackSame"
            case .worse: return "feedbackWorse"
            }
        }
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text(headline)
                .font(.title2)
                .accessibilityIdentifier("resultHeadline")

            VStack(spacing: 12) {
                ForEach(Choice.allCases) { choice in
                    Button {
                        // Sprint 7 에서 여기에 피드백 저장이 들어간다.
                        coordinator.returnHome()
                    } label: {
                        Text(choice.rawValue)
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

    private var headline: String {
        coordinator.finishReason == .cancelled ? "쉼을 멈췄어요" : "조금 나아졌나요?"
    }
}

#Preview {
    RestResultView()
        .environmentObject(RestFlowCoordinator.previewCompleted())
}
