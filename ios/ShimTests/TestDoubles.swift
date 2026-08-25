//
//  TestDoubles.swift
//  ShimTests
//
//  Sprint 2 테스트용 시계와 tick 신호.
//
//  실제 시간을 기다리지 않고 시작 직후 / 경과 / 종료 직전 / 종료 시점 /
//  종료 초과 / background 복귀를 결정적으로 재현하기 위한 것이다.
//

import Foundation
@testable import Shim

/// 손으로 앞당길 수 있는 시계.
final class MutableClock: Clock {
    private(set) var now: Date

    init(now: Date = Date(timeIntervalSince1970: 1_700_000_000)) {
        self.now = now
    }

    /// 시간을 앞으로 보낸다.
    func advance(by interval: TimeInterval) {
        now = now.addingTimeInterval(interval)
    }

    /// 분 단위로 앞으로 보낸다.
    func advance(minutes: Double) {
        advance(by: minutes * 60)
    }
}

/// 자동으로 돌지 않는 tick 신호.
///
/// 테스트가 `fire()` 를 부를 때만 tick 이 발생한다.
/// 앱이 background 에서 suspend 되어 tick 이 아예 오지 않는 상황도
/// "fire 를 부르지 않는 것"으로 그대로 재현할 수 있다.
@MainActor
final class ManualTickScheduler: TickScheduler {
    private var onTick: (() -> Void)?

    private(set) var isRunning = false
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var lastInterval: TimeInterval?

    func start(interval: TimeInterval, onTick: @escaping () -> Void) {
        startCount += 1
        lastInterval = interval
        isRunning = true
        self.onTick = onTick
    }

    func stop() {
        stopCount += 1
        isRunning = false
        onTick = nil
    }

    /// tick 을 한 번 발생시킨다. 멈춰 있으면 아무 일도 하지 않는다.
    func fire() {
        onTick?()
    }

    /// tick 을 여러 번 발생시킨다.
    func fire(times: Int) {
        for _ in 0..<times { fire() }
    }
}
