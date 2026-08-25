//
//  MockRestPlanFactory.swift
//  Shim
//
//  AI 연결 전까지 쓰는 Mock RestPlan. (운영규칙 §7 — "AI 연결 전에는
//  Mock RestPlan 으로 개발한다.")
//
//  ⚠️ 이것은 Mock 이다. 실제 AI 응답이 아니다.
//     Backend 연결은 Sprint 8, AI 연결은 Sprint 9 다.
//

import Foundation

enum MockRestPlanFactory {

    /// docs/PRODUCT.md §10 의 대표 사용자 흐름을 그대로 옮긴 기본 계획.
    ///
    /// "머리가 너무 복잡해" → 10분 · 음악 + 천천히 걷기 · 화면 최소화
    static func defaultPlan() -> RestPlan {
        RestPlan(
            id: "mock-001",
            durationMinutes: 10,
            restType: .environmentReset,
            audio: .calmAcoustic,
            movement: .slowWalk,
            screenMode: .minimal,
            brightness: 0.25,
            watchGuidance: false,
            endCheckin: true,
            guidanceMessages: ["휴대폰은 내려놓고 천천히 걸어보세요."]
        )
    }

    /// 테스트에서 짧은 쉼이 필요할 때 쓴다.
    ///
    /// - Note: Sprint 2 의 TimerService 테스트에서 짧은 duration 주입에 사용한다.
    ///   (docs/IOS_SPEC.md §7.1)
    static func shortPlan(minutes: Int = 1) -> RestPlan {
        RestPlan(
            id: "mock-short",
            durationMinutes: minutes,
            restType: .environmentReset,
            audio: .silence,
            movement: .none,
            screenMode: .minimal,
            brightness: nil,
            watchGuidance: false,
            endCheckin: true,
            guidanceMessages: ["잠시 눈을 감고 숨을 고르세요."]
        )
    }
}
