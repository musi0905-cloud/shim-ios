//
//  RestPlanValidatorTests.swift
//  ShimTests
//
//  AI 가 준 값을 앱이 그대로 믿지 않는다는 규칙을 테스트로 고정한다.
//  docs/PRODUCT.md §5 / docs/IOS_SPEC.md §7.3, §13
//

import XCTest
@testable import Shim

final class RestPlanValidatorTests: XCTestCase {

    private func plan(
        durationMinutes: Int = 10,
        brightness: Double? = 0.25,
        guidanceMessages: [String] = ["휴대폰은 내려놓고 천천히 걸어보세요."]
    ) -> RestPlan {
        RestPlan(
            id: "test",
            durationMinutes: durationMinutes,
            restType: .environmentReset,
            audio: .calmAcoustic,
            movement: .slowWalk,
            screenMode: .minimal,
            brightness: brightness,
            guidanceMessages: guidanceMessages
        )
    }

    // MARK: - 통과

    func testValidPlanPassesUnchanged() throws {
        let input = plan()
        let result = try RestPlanValidator.validate(input)

        XCTAssertEqual(result.plan, input)
        XCTAssertTrue(result.adjustments.isEmpty, "보정할 것이 없어야 한다")
    }

    func testNilBrightnessIsAllowed() throws {
        let result = try RestPlanValidator.validate(plan(brightness: nil))
        XCTAssertNil(result.plan.brightness)
        XCTAssertTrue(result.adjustments.isEmpty)
    }

    func testBoundaryDurationsAreAllowed() throws {
        XCTAssertNoThrow(try RestPlanValidator.validate(plan(durationMinutes: 1)))
        XCTAssertNoThrow(try RestPlanValidator.validate(plan(durationMinutes: 60)))
    }

    func testBoundaryBrightnessValuesAreNotAdjusted() throws {
        for value in [0.0, 1.0] {
            let result = try RestPlanValidator.validate(plan(brightness: value))
            XCTAssertEqual(result.plan.brightness, value)
            XCTAssertTrue(result.adjustments.isEmpty, "\(value) 는 유효 범위 경계다")
        }
    }

    // MARK: - 보정 (clamp)

    /// 밝기가 범위를 벗어나도 쉼 자체는 실행되어야 한다.
    /// docs/IOS_SPEC.md §7.3 — "밝기 변경 실패가 전체 쉼 실행 실패로 이어지지 않도록 한다."
    func testBrightnessAboveRangeIsClamped() throws {
        let result = try RestPlanValidator.validate(plan(brightness: 4.2))

        XCTAssertEqual(result.plan.brightness, 1.0)
        XCTAssertEqual(result.adjustments, [.brightnessClamped(from: 4.2, to: 1.0)])
    }

    func testBrightnessBelowRangeIsClamped() throws {
        let result = try RestPlanValidator.validate(plan(brightness: -1.0))

        XCTAssertEqual(result.plan.brightness, 0.0)
        XCTAssertEqual(result.adjustments, [.brightnessClamped(from: -1.0, to: 0.0)])
    }

    func testExcessGuidanceMessagesAreTruncated() throws {
        let many = (1...10).map { "안내 \($0)" }
        let result = try RestPlanValidator.validate(plan(guidanceMessages: many))

        XCTAssertEqual(result.plan.guidanceMessages.count, RestPlanValidator.maxGuidanceMessages)
        XCTAssertEqual(result.plan.guidanceMessages.first, "안내 1")
        XCTAssertEqual(
            result.adjustments,
            [.guidanceMessagesTruncated(from: 10, to: RestPlanValidator.maxGuidanceMessages)]
        )
    }

    /// 보정은 조용히 일어나지 않고 기록에 남아야 한다.
    func testMultipleAdjustmentsAreAllRecorded() throws {
        let result = try RestPlanValidator.validate(
            plan(brightness: 9.9, guidanceMessages: (1...5).map { "안내 \($0)" })
        )
        XCTAssertEqual(result.adjustments.count, 2)
    }

    // MARK: - 거부 (reject)

    /// 0분 쉼은 실행 자체가 말이 되지 않는다.
    func testZeroDurationIsRejected() {
        XCTAssertThrowsError(try RestPlanValidator.validate(plan(durationMinutes: 0))) { error in
            XCTAssertEqual(
                error as? RestPlanValidationError,
                .durationOutOfRange(minutes: 0, allowed: RestPlanValidator.allowedDurationMinutes)
            )
        }
    }

    func testNegativeDurationIsRejected() {
        XCTAssertThrowsError(try RestPlanValidator.validate(plan(durationMinutes: -5)))
    }

    func testExcessiveDurationIsRejected() {
        XCTAssertThrowsError(try RestPlanValidator.validate(plan(durationMinutes: 600)))
    }

    // MARK: - 계약 흐름

    /// AI JSON → decoding → validation 전체 경로가 이어져야 한다.
    func testDecodedPlanFlowsThroughValidation() throws {
        let json = """
        {
          "duration_minutes": 10,
          "rest_type": "environment_reset",
          "audio": "calm_acoustic",
          "movement": "slow_walk",
          "brightness": 7.5,
          "screen_mode": "minimal"
        }
        """.data(using: .utf8)!

        let decoded = try RestPlan.decode(from: json)
        let validated = try RestPlanValidator.validate(decoded)

        XCTAssertEqual(validated.plan.brightness, 1.0, "AI 가 준 7.5 는 그대로 실행되면 안 된다")
        XCTAssertEqual(validated.durationSeconds, 600)
    }
}
