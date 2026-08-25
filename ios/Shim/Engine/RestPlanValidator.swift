//
//  RestPlanValidator.swift
//  Shim
//
//  RestPlan 을 실행하기 전에 통과시켜야 하는 관문.
//
//  docs/PRODUCT.md §5 — "앱은 이 결과를 검증한 뒤 허용된 기능만 실행한다."
//  docs/IOS_SPEC.md §13 — "AI 가 반환한 RestPlan 을 앱이 그대로 맹신하지 않는다."
//
//  파이프라인에서의 위치:
//      AI JSON → decoding → **validation** → RestEngine → Execution Layer
//
//  두 가지 처리 방식을 구분한다 (docs/IOS_SPEC.md §5):
//    - 보정(clamp): 값의 의미는 맞지만 범위를 벗어난 경우. 안전한 값으로 조정한다.
//    - 거부(reject): 실행 자체가 말이 되지 않는 경우. 오류를 던진다.
//
//  이 타입은 어떤 iOS 시스템 프레임워크도 import 하지 않는다. 순수 규칙이다.
//

import Foundation

/// 검증을 통과한 RestPlan.
///
/// 실행 계층은 `RestPlan` 이 아니라 이 타입만 받는다.
/// 검증되지 않은 계획이 실행되는 경로를 타입 수준에서 막기 위해서다.
struct ValidatedRestPlan: Equatable {
    /// 보정이 적용된 계획.
    let plan: RestPlan
    /// 검증 과정에서 적용한 보정 내역. 비어 있으면 원본 그대로다.
    let adjustments: [RestPlanAdjustment]

    /// 실행 계층이 쓰는 편의 접근자.
    var durationSeconds: Int { plan.durationSeconds }
}

/// 검증이 값을 바꾼 내역.
///
/// 조용히 바꾸지 않고 기록에 남긴다. 어떤 AI 응답이 자주 보정되는지
/// 파악해야 프롬프트나 Rest Engine 규칙을 고칠 수 있다.
enum RestPlanAdjustment: Equatable {
    /// 밝기가 허용 범위를 벗어나 보정됨.
    case brightnessClamped(from: Double, to: Double)
    /// 안내 문장이 너무 많아 잘라냄.
    case guidanceMessagesTruncated(from: Int, to: Int)
}

/// 검증 실패 사유.
enum RestPlanValidationError: Error, Equatable {
    /// 쉼 길이가 허용 범위를 벗어남.
    case durationOutOfRange(minutes: Int, allowed: ClosedRange<Int>)
}

extension RestPlanValidationError: CustomStringConvertible {
    var description: String {
        switch self {
        case let .durationOutOfRange(minutes, allowed):
            return "쉼 길이 \(minutes)분은 허용 범위(\(allowed.lowerBound)~\(allowed.upperBound)분)를 벗어난다."
        }
    }
}

/// RestPlan 검증기.
enum RestPlanValidator {

    /// 허용하는 쉼 길이(분).
    ///
    /// docs/PRODUCT.md §1 은 "3분, 5분, 10분, 20분 정도"를, §7 은 선호 시간
    /// "8~15분"을 언급한다. 상한을 60분으로 두어 명백히 잘못된 값만 거부한다.
    /// 제품이 권장 범위를 좁히려면 Rest Engine 이 할 일이지 Validator 가 아니다.
    static let allowedDurationMinutes: ClosedRange<Int> = 1...60

    /// 허용하는 화면 밝기.
    ///
    /// `UIScreen.brightness` 의 유효 범위다. (docs/PRODUCT.md §8, IOS_SPEC.md §7.3)
    static let allowedBrightness: ClosedRange<Double> = 0.0...1.0

    /// RestSession 화면에 남길 안내 문장의 최대 개수.
    ///
    /// 화면은 한 문장만 쓴다(IOS_SPEC.md §8.2). 여유를 두되 무한정 받지 않는다.
    static let maxGuidanceMessages = 3

    /// RestPlan 을 검증하고 필요한 보정을 적용한다.
    ///
    /// - Throws: `RestPlanValidationError` — 실행할 수 없는 계획인 경우.
    static func validate(_ plan: RestPlan) throws -> ValidatedRestPlan {
        var adjustments: [RestPlanAdjustment] = []

        // 1. 쉼 길이 — 거부 대상. 0분이나 음수는 실행 자체가 불가능하다.
        guard allowedDurationMinutes.contains(plan.durationMinutes) else {
            throw RestPlanValidationError.durationOutOfRange(
                minutes: plan.durationMinutes,
                allowed: allowedDurationMinutes
            )
        }

        // 2. 밝기 — 보정 대상.
        //    밝기 문제가 쉼 전체를 막아서는 안 된다. (IOS_SPEC.md §7.3)
        var brightness = plan.brightness
        if let requested = brightness, !allowedBrightness.contains(requested) {
            let clamped = min(max(requested, allowedBrightness.lowerBound),
                              allowedBrightness.upperBound)
            brightness = clamped
            adjustments.append(.brightnessClamped(from: requested, to: clamped))
        }

        // 3. 안내 문장 — 보정 대상.
        var guidanceMessages = plan.guidanceMessages
        if guidanceMessages.count > maxGuidanceMessages {
            let original = guidanceMessages.count
            guidanceMessages = Array(guidanceMessages.prefix(maxGuidanceMessages))
            adjustments.append(
                .guidanceMessagesTruncated(from: original, to: guidanceMessages.count)
            )
        }

        let sanitized = RestPlan(
            id: plan.id,
            durationMinutes: plan.durationMinutes,
            restType: plan.restType,
            audio: plan.audio,
            movement: plan.movement,
            screenMode: plan.screenMode,
            brightness: brightness,
            watchGuidance: plan.watchGuidance,
            endCheckin: plan.endCheckin,
            guidanceMessages: guidanceMessages
        )

        return ValidatedRestPlan(plan: sanitized, adjustments: adjustments)
    }
}
