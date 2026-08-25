//
//  RestPlanDecodingTests.swift
//  ShimTests
//
//  RestPlan 은 AI → Backend → 앱을 잇는 API 계약이다.
//  계약이 깨지는 방식을 테스트로 고정한다.
//
//  docs/IOS_SPEC.md §10 — 유닛 테스트: RestPlan decoding / validation
//

import XCTest
@testable import Shim

final class RestPlanDecodingTests: XCTestCase {

    // MARK: - 정상 디코딩

    /// docs/PRODUCT.md §5 의 예시 JSON 이 그대로 디코딩되어야 한다.
    /// 이 테스트가 깨지면 AI 와의 계약이 깨진 것이다.
    func testDecodesProductSpecExampleJSON() throws {
        let json = """
        {
          "duration_minutes": 10,
          "rest_type": "environment_reset",
          "audio": "calm_acoustic",
          "movement": "slow_walk",
          "brightness": 0.25,
          "watch_guidance": true,
          "screen_mode": "minimal",
          "end_checkin": true
        }
        """.data(using: .utf8)!

        let plan = try RestPlan.decode(from: json)

        XCTAssertEqual(plan.durationMinutes, 10)
        XCTAssertEqual(plan.restType, .environmentReset)
        XCTAssertEqual(plan.audio, .calmAcoustic)
        XCTAssertEqual(plan.movement, .slowWalk)
        XCTAssertEqual(plan.brightness, 0.25)
        XCTAssertEqual(plan.screenMode, .minimal)
        XCTAssertTrue(plan.watchGuidance)
        XCTAssertTrue(plan.endCheckin)
    }

    /// 선택 필드가 없어도 문서화된 기본값으로 디코딩되어야 한다.
    func testDecodesWithOptionalFieldsOmitted() throws {
        let json = """
        {
          "duration_minutes": 5,
          "rest_type": "environment_reset",
          "audio": "silence",
          "movement": "none",
          "screen_mode": "dark"
        }
        """.data(using: .utf8)!

        let plan = try RestPlan.decode(from: json)

        XCTAssertNil(plan.brightness, "brightness 가 없으면 nil — 밝기를 바꾸지 않는다")
        XCTAssertFalse(plan.watchGuidance, "기본값 false")
        XCTAssertTrue(plan.endCheckin, "기본값 true — 종료 후 1회 피드백")
        XCTAssertEqual(plan.guidanceMessages, [])
        XCTAssertFalse(plan.id.isEmpty, "id 가 없으면 앱이 생성한다")
    }

    func testDecodesGuidanceMessagesAndID() throws {
        let json = """
        {
          "id": "plan-42",
          "duration_minutes": 3,
          "rest_type": "environment_reset",
          "audio": "nature_sound",
          "movement": "stretch",
          "screen_mode": "minimal",
          "guidance_messages": ["어깨를 천천히 돌려보세요."]
        }
        """.data(using: .utf8)!

        let plan = try RestPlan.decode(from: json)

        XCTAssertEqual(plan.id, "plan-42")
        XCTAssertEqual(plan.guidanceMessages, ["어깨를 천천히 돌려보세요."])
        XCTAssertEqual(plan.primaryGuidanceMessage, "어깨를 천천히 돌려보세요.")
    }

    // MARK: - 디코딩 실패

    /// 지원하지 않는 enum 값은 조용히 넘어가지 않고 실패해야 한다.
    ///
    /// AI 가 계약에 없는 값을 보내면 앱이 알아야 한다.
    /// docs/DECISIONS.md D-010 — 알 수 없는 enum 값은 거부한다.
    func testRejectsUnsupportedEnumValue() throws {
        let json = """
        {
          "duration_minutes": 10,
          "rest_type": "environment_reset",
          "audio": "heavy_metal",
          "movement": "slow_walk",
          "screen_mode": "minimal"
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try RestPlan.decode(from: json)) { error in
            guard case DecodingError.dataCorrupted = error else {
                return XCTFail("알 수 없는 enum 값은 dataCorrupted 여야 한다. 실제: \(error)")
            }
        }
    }

    func testRejectsUnsupportedRestType() throws {
        let json = """
        {
          "duration_minutes": 10,
          "rest_type": "deep_meditation_retreat",
          "audio": "silence",
          "movement": "none",
          "screen_mode": "minimal"
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try RestPlan.decode(from: json))
    }

    /// 필수 필드가 없으면 실패해야 한다.
    func testRejectsMissingRequiredField() throws {
        let json = """
        {
          "rest_type": "environment_reset",
          "audio": "silence",
          "movement": "none",
          "screen_mode": "minimal"
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try RestPlan.decode(from: json)) { error in
            guard case DecodingError.keyNotFound(let key, _) = error else {
                return XCTFail("필수 필드 누락은 keyNotFound 여야 한다. 실제: \(error)")
            }
            XCTAssertEqual(key.stringValue, "duration_minutes")
        }
    }

    /// 타입이 다르면 실패해야 한다.
    func testRejectsWrongType() throws {
        let json = """
        {
          "duration_minutes": "십분",
          "rest_type": "environment_reset",
          "audio": "silence",
          "movement": "none",
          "screen_mode": "minimal"
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try RestPlan.decode(from: json)) { error in
            guard case DecodingError.typeMismatch = error else {
                return XCTFail("타입 불일치는 typeMismatch 여야 한다. 실제: \(error)")
            }
        }
    }

    /// JSON 자체가 깨져 있으면 실패해야 한다.
    func testRejectsMalformedJSON() throws {
        let json = "{ this is not json ".data(using: .utf8)!
        XCTAssertThrowsError(try RestPlan.decode(from: json))
    }

    /// 빈 응답에도 크래시하지 않아야 한다.
    func testRejectsEmptyData() throws {
        XCTAssertThrowsError(try RestPlan.decode(from: Data()))
    }

    // MARK: - 왕복

    /// 인코딩 후 다시 디코딩해도 값이 보존되어야 한다.
    /// Backend 로 계획을 되돌려 보낼 때 필요하다.
    func testRoundTripPreservesValues() throws {
        let original = MockRestPlanFactory.defaultPlan()
        let decoded = try RestPlan.decode(from: original.encoded())
        XCTAssertEqual(decoded, original)
    }

    /// 인코딩 결과의 키가 snake_case 여야 한다. Backend 계약이다.
    func testEncodesUsingSnakeCaseKeys() throws {
        let data = try MockRestPlanFactory.defaultPlan().encoded()
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        XCTAssertNotNil(object["duration_minutes"])
        XCTAssertNotNil(object["rest_type"])
        XCTAssertNotNil(object["screen_mode"])
        XCTAssertNotNil(object["end_checkin"])
        XCTAssertNil(object["durationMinutes"], "camelCase 키가 있으면 계약 위반이다")
    }

    // MARK: - 파생 값

    func testDurationSecondsDerivesFromMinutes() {
        let plan = MockRestPlanFactory.shortPlan(minutes: 3)
        XCTAssertEqual(plan.durationSeconds, 180)
    }
}
