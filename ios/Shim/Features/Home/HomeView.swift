//
//  HomeView.swift
//  Shim
//
//  docs/IOS_SPEC.md §8.1
//    "제품 철학상 복잡한 대시보드를 만들지 않는다."
//    대표 CTA: "쉼 시작". 개발 초기에는 Mock 버튼 사용 가능.
//
//  Sprint 1 범위: 상태 선택 영역과 한 줄 자유 입력은 아직 없다.
//  Mock RestPlan 하나로 흐름만 확인한다.
//
//  UI 는 시스템 기본 컴포넌트만 쓴다. 디자인 완성은 이 Sprint 의 목표가 아니다.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var coordinator: RestFlowCoordinator

    private let plan = MockRestPlanFactory.defaultPlan()

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 8) {
                Text("쉼")
                    .font(.system(size: 44, weight: .light))
                Text("잠시 나만을 위한 시간")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                coordinator.start(with: plan)
            } label: {
                Text("\(plan.durationMinutes)분 쉼 시작")
                    .font(.title3)
                    .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("startRestButton")

            if let errorMessage = coordinator.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("homeErrorMessage")
            }

            Spacer().frame(height: 24)
        }
        .padding(.horizontal, 24)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
    .environmentObject(RestFlowCoordinator())
}
