//
//  Clock.swift
//  Shim
//
//  "지금 몇 시인가"를 주입 가능하게 만든다.
//
//  타이머가 `Date()` 를 직접 부르면 테스트가 실제 시간을 기다려야 한다.
//  Clock 을 주입하면 시작 직후 / 1분 경과 / 종료 직전 / 종료 시점 /
//  종료 초과 / background 복귀를 결정적으로 재현할 수 있다.
//

import Foundation

/// 현재 시각 제공자.
protocol Clock {
    var now: Date { get }
}

/// 실제 시스템 시계.
struct SystemClock: Clock {
    var now: Date { Date() }
}
