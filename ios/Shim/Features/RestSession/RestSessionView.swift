//
//  RestSessionView.swift
//  Shim
//
//  docs/IOS_SPEC.md §8.2
//    화면은 최대한 단순해야 한다 — 남은 시간 / 한 문장 안내 / 중단 버튼.
//    불필요한 네비게이션, 피드, 추천 콘텐츠 금지. 기본적으로 어두운 화면.
//
//  남은 시간은 RestFlowCoordinator 가 밀어주는 값을 그대로 표시한다.
//  이 뷰는 Timer 도 Date 도 직접 다루지 않는다. 시간 계산은 전부
//  RestTimerService 의 책임이다.
//
//      RestSessionView → RestFlowCoordinator → RestTimerService
//

import SwiftUI

struct RestSessionView: View {
    @EnvironmentObject private var coordinator: RestFlowCoordinator

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                Text(remainingText)
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

                // 시간이 다 되면 자동으로 종료된다. 사용자가 눌러야 할 것은 없다.
                // 정말 끝내고 싶을 때를 위한 하나의 출구만 둔다.
                // 이것은 정상 완료가 아니라 cancel 이다.
                Button("쉼 그만하기") {
                    coordinator.cancel()
                }
                .foregroundStyle(.white.opacity(0.6))
                .accessibilityIdentifier("cancelRestButton")

                Spacer().frame(height: 24)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    /// 남은 시간을 mm:ss 로 표시한다.
    ///
    /// 올림을 쓴다. 599.4초가 남았을 때 09:59 가 아니라 10:00 으로 보여야
    /// 시작 직후 화면이 계획한 길이와 어긋나 보이지 않는다.
    private var remainingText: String {
        let total = Int(coordinator.remainingSeconds.rounded(.up))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

#Preview {
    RestSessionView()
        .environmentObject(RestFlowCoordinator.previewRunning())
}
