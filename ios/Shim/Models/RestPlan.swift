//
//  RestPlan.swift
//  Shim
//
//  ⚠️ 이 타입은 「쉼」의 API 계약서다.
//
//  AI(OpenAI Structured Output) → Backend → iOS 앱 → 실행 계층이 전부 이
//  스키마를 기준으로 연결된다. 필드를 바꾸면 Backend 의 JSON Schema 와
//  docs/PRODUCT.md §5, docs/IOS_SPEC.md §5 를 함께 갱신해야 한다.
//
//  실행 파이프라인 (docs/DECISIONS.md D-010):
//
//      AI JSON
//        ↓  RestPlan decoding      ← 이 파일
//        ↓  RestPlan validation    ← Engine/RestPlanValidator.swift
//        ↓  RestEngine             ← 이후 Sprint
//        ↓  Execution Layer        ← 이후 Sprint
//
//  RestPlan 은 "무엇을 실행할지"만 표현한다. 어떻게 실행할지는 모른다.
//  따라서 이 파일은 어떤 iOS 시스템 프레임워크도 import 하지 않는다.
//

import Foundation

/// AI 가 설계한 하나의 쉼 계획.
///
/// JSON 키는 snake_case 다. AI/Backend 가 반환하는 형식이기 때문이다
/// (docs/PRODUCT.md §5).
///
/// ```json
/// {
///   "duration_minutes": 10,
///   "rest_type": "environment_reset",
///   "audio": "calm_acoustic",
///   "movement": "slow_walk",
///   "brightness": 0.25,
///   "screen_mode": "minimal",
///   "watch_guidance": true,
///   "end_checkin": true
/// }
/// ```
struct RestPlan: Codable, Equatable, Identifiable {

    // MARK: 필수 필드 — AI 가 반드시 채워야 한다

    /// 쉼의 길이(분).
    let durationMinutes: Int

    /// 쉼의 유형.
    let restType: RestType

    /// 재생할 오디오 유형.
    let audio: AudioMode

    /// 권유할 움직임.
    let movement: MovementType

    /// 쉼 중 화면 표시 방식.
    let screenMode: ScreenMode

    // MARK: 선택 필드 — 없으면 안전한 기본값을 쓴다

    /// 목표 화면 밝기 (0.0 ~ 1.0). `nil` 이면 밝기를 바꾸지 않는다.
    ///
    /// - Important: 이 값은 기기 기능과 직접 연결된다. AI 가 준 숫자를 그대로
    ///   믿지 않는다. 반드시 `RestPlanValidator` 를 거쳐 범위를 보정한 뒤
    ///   실행 계층으로 넘긴다. (docs/IOS_SPEC.md §7.3)
    let brightness: Double?

    /// Apple Watch 로 안내를 보낼지 여부.
    ///
    /// - Note: 계약에는 포함하되 실제 동작은 Sprint 11(Apple Watch PoC)에서
    ///   구현한다. 지금은 값만 보존한다.
    let watchGuidance: Bool

    /// 쉼 종료 후 1회 피드백을 받을지 여부. (docs/IOS_SPEC.md §8.3)
    let endCheckin: Bool

    /// 쉼 중 화면에 보여줄 짧은 안내 문장. (docs/IOS_SPEC.md §5)
    ///
    /// RestSession 화면은 이 중 첫 문장만 쓴다. 긴 안내는 제품 철학에 어긋난다.
    let guidanceMessages: [String]

    /// 이 계획의 식별자.
    ///
    /// AI 응답에 없으면 앱이 생성한다. Sprint 7 에서 피드백·기록을 이 id 로 묶는다.
    let id: String

    // MARK: - JSON 매핑

    private enum CodingKeys: String, CodingKey {
        case durationMinutes = "duration_minutes"
        case restType = "rest_type"
        case audio
        case movement
        case screenMode = "screen_mode"
        case brightness
        case watchGuidance = "watch_guidance"
        case endCheckin = "end_checkin"
        case guidanceMessages = "guidance_messages"
        case id
    }

    init(
        id: String = UUID().uuidString,
        durationMinutes: Int,
        restType: RestType,
        audio: AudioMode,
        movement: MovementType,
        screenMode: ScreenMode,
        brightness: Double? = nil,
        watchGuidance: Bool = false,
        endCheckin: Bool = true,
        guidanceMessages: [String] = []
    ) {
        self.id = id
        self.durationMinutes = durationMinutes
        self.restType = restType
        self.audio = audio
        self.movement = movement
        self.screenMode = screenMode
        self.brightness = brightness
        self.watchGuidance = watchGuidance
        self.endCheckin = endCheckin
        self.guidanceMessages = guidanceMessages
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // 필수 필드. 없거나 알 수 없는 enum 값이면 throw 한다.
        // 조용히 기본값으로 대체하면 AI 가 잘못된 계획을 보내도 알 수 없다.
        durationMinutes = try container.decode(Int.self, forKey: .durationMinutes)
        restType = try container.decode(RestType.self, forKey: .restType)
        audio = try container.decode(AudioMode.self, forKey: .audio)
        movement = try container.decode(MovementType.self, forKey: .movement)
        screenMode = try container.decode(ScreenMode.self, forKey: .screenMode)

        // 선택 필드. 없으면 문서화된 기본값을 쓴다.
        brightness = try container.decodeIfPresent(Double.self, forKey: .brightness)
        watchGuidance = try container.decodeIfPresent(Bool.self, forKey: .watchGuidance) ?? false
        endCheckin = try container.decodeIfPresent(Bool.self, forKey: .endCheckin) ?? true
        guidanceMessages = try container.decodeIfPresent([String].self, forKey: .guidanceMessages) ?? []
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
    }

    // MARK: - 파생 값

    /// 쉼의 길이(초).
    ///
    /// 계약은 분 단위이고 실행 계층(TimerService)은 초 단위를 쓴다.
    /// 두 값을 각각 저장하면 어긋날 수 있으므로 여기서 파생시킨다.
    var durationSeconds: Int {
        durationMinutes * 60
    }

    /// RestSession 화면에 보여줄 한 문장. 없으면 `nil`.
    var primaryGuidanceMessage: String? {
        guidanceMessages.first
    }
}

// MARK: - JSON 편의 API

extension RestPlan {
    /// AI/Backend 가 반환한 JSON 을 RestPlan 으로 디코딩한다.
    ///
    /// - Throws: `DecodingError` — 필수 필드 누락, 타입 불일치,
    ///   또는 지원하지 않는 enum 값인 경우.
    static func decode(from data: Data) throws -> RestPlan {
        try JSONDecoder().decode(RestPlan.self, from: data)
    }

    /// 테스트와 Backend 연동 확인을 위한 인코딩.
    func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }
}
