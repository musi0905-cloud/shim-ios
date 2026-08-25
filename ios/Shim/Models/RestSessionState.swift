//
//  RestSessionState.swift
//  Shim
//
//  쉼 세션의 상태. docs/IOS_SPEC.md §9 의 최소 상태 집합을 그대로 따른다.
//
//  상태 전이는 한 곳(RestFlowCoordinator)에서만 관리한다.
//  중복 start 로 두 개의 Timer 나 AudioSession 이 생기지 않게 막는 것이
//  이 타입의 존재 이유다.
//

import Foundation

enum RestSessionState: String, Equatable, CaseIterable {
    case idle
    case preparing
    case running
    case finishing
    case completed
    case cancelled
    case failed

    /// 새 쉼을 시작할 수 있는 상태인지.
    ///
    /// `preparing` / `running` / `finishing` 중에는 시작할 수 없다.
    /// docs/IOS_SPEC.md §9 — "running 중 다시 시작 버튼이 눌려도
    /// 두 개의 Timer 나 AudioSession 이 생성되지 않아야 한다."
    var canStart: Bool {
        switch self {
        case .idle, .completed, .cancelled, .failed:
            return true
        case .preparing, .running, .finishing:
            return false
        }
    }

    /// 쉼이 진행 중인 상태인지.
    var isActive: Bool {
        switch self {
        case .preparing, .running, .finishing:
            return true
        case .idle, .completed, .cancelled, .failed:
            return false
        }
    }
}
