//
//  RootView.swift
//  Shim
//
//  Home → RestSession → RestResult → Home 흐름을 담는 컨테이너.
//
//  네비게이션 경로는 RestFlowCoordinator 가 단일 소스로 관리한다.
//  뷰는 경로를 직접 바꾸지 않고 coordinator 에 요청만 한다.
//

import SwiftUI

struct RootView: View {
    @StateObject private var coordinator = RestFlowCoordinator()

    var body: some View {
        NavigationStack(path: pathBinding) {
            HomeView()
                .navigationDestination(for: RestFlowCoordinator.Route.self) { route in
                    switch route {
                    case .session:
                        RestSessionView()
                    case .result:
                        RestResultView()
                    }
                }
        }
        .environmentObject(coordinator)
    }

    /// NavigationStack 은 쓰기 가능한 Binding 을 요구하지만, 경로 변경 권한은
    /// coordinator 에만 둔다. 시스템이 되돌리는 pop 만 홈 복귀로 반영한다.
    private var pathBinding: Binding<[RestFlowCoordinator.Route]> {
        Binding(
            get: { coordinator.path },
            set: { newPath in
                if newPath.isEmpty && !coordinator.path.isEmpty {
                    coordinator.returnHome()
                }
            }
        )
    }
}

#Preview {
    RootView()
}
