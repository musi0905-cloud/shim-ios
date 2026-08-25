//
//  RestSessionView.swift
//  Shim
//
//  docs/IOS_SPEC.md §8.2
//    화면은 최대한 단순해야 한다 — 남은 시간 / 한 문장 안내 / 중단 버튼.
//    불필요한 네비게이션, 피드, 추천 콘텐츠 금지. 기본적으로 어두운 화면.
//
//  Sprint 1 범위: 타이머는 붙이지 않는다(Sprint 2).
//  여기 보이는 시간은 계획된 길이일 뿐 카운트다운이 아니다.
//

import SwiftUI

struct RestSessionView: View {
    @EnvironmentObject private var coordinator: RestFlowCoordinator

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Sprint 2 에서 TimerService 의 남은 시간으로 교체된다.
                Text(plannedDurationText)
                    .font(.system(size: 64, weight: .thin, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("remainingTime")

                if let guidance = coordinator.activePlan?.plan.primaryGuidanceMessage {
                    Text(guidance)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .accessibilityIdentifier("guidanceMessage")
                }

                Spacer()

                Button("쉼 중단") {
                    coordinator.cancel()
                }
                .foregroundStyle(.white.opacity(0.6))
                .accessibilityIdentifier("cancelRestButton")

                // Sprint 1 에는 타이머가 없어 자연 종료가 발생하지 않는다.
                // 정상 종료 경로를 Simulator/CI 에서 확인할 수 있도록 둔 임시 버튼이다.
                // Sprint 2 에서 TimerService 가 만료를 알리면 제거한다.
                Button("쉼 종료 (임시)") {
                    coordinator.finish()
                }
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.35))
                .accessibilityIdentifier("finishRestButton")

                Spacer().frame(height: 24)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var plannedDurationText: String {
        let seconds = coordinator.activePlan?.durationSeconds ?? 0
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

#Preview {
    RestSessionView()
        .environmentObject(RestFlowCoordinator.previewRunning())
}
