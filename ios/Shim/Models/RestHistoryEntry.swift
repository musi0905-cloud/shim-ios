//
//  RestHistoryEntry.swift
//  Shim
//
//  한 번의 쉼에 대한 기록. 개인화의 원천 데이터다.
//
//  docs/PRODUCT.md §7 — 장기적으로 축적해야 할 핵심 자산은
//  "어떤 상태의 사람에게 어떤 쉼 조합이 실제로 도움이 되었는가" 다.
//
//  ── 프라이버시 (docs/PRODUCT.md §12, D-022) ──────────────────────────
//
//  **자유 텍스트 원문을 담을 필드가 아예 없다.**
//  "저장하지 않는다" 가 아니라 "저장할 자리가 없다" 로 지킨다.
//  Sprint 10 에서 한 줄 입력이 생겨도 원문이 아니라 파생된 구조값만 들어와야 한다.
//  `RestHistoryEntryTests.testEncodedKeysAreExactlyTheAllowedSet` 이 이를 고정한다.
//
//  위치·건강 데이터도 담지 않는다. 애초에 수집하지 않는다.
//
//  ── 왜 계획 시간과 실제 시간을 둘 다 담나 ────────────────────────────
//
//  10분 계획을 2분 만에 취소한 사람과 9분 50초에 취소한 사람을 똑같이
//  `cancelled` 로만 보면 데이터 가치가 떨어진다.
//  완료율(docs/PRODUCT.md §14)과 개인화 모두 실제 지속시간을 필요로 한다.
//

import Foundation

struct RestHistoryEntry: Codable, Equatable, Identifiable {

    /// 쉼이 어떻게 끝났는지.
    enum Outcome: String, Codable, Equatable {
        /// 시간이 다 되어 자연 종료됐다.
        case completed
        /// 사용자가 중간에 그만뒀다.
        case cancelled
    }

    let id: String
    /// 이 기록을 만든 RestPlan 의 id.
    let planID: String

    let startedAt: Date
    let endedAt: Date

    /// 계획된 길이(분).
    let plannedDurationMinutes: Int
    /// 실제로 지속된 시간(초). 항상 0 이상이다.
    let actualDurationSeconds: Int

    let restType: RestType
    let audio: AudioMode
    let movement: MovementType

    let outcome: Outcome
    /// 사용자가 고른 응답. 묻지 않았거나 건너뛰었으면 `nil`.
    let feedback: RestFeedback?

    // MARK: - JSON 매핑
    //
    // RestPlan 과 같은 snake_case 를 쓴다 (D-010). 이후 Backend 로 보낼 때
    // 변환 계층을 만들지 않기 위해서다.

    private enum CodingKeys: String, CodingKey {
        case id
        case planID = "plan_id"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case plannedDurationMinutes = "planned_duration_minutes"
        case actualDurationSeconds = "actual_duration_seconds"
        case restType = "rest_type"
        case audio
        case movement
        case outcome
        case feedback
    }

    /// 저장할 기록을 만든다.
    ///
    /// `actualDurationSeconds` 는 `startedAt` 과 `endedAt` 의 차이에서 계산한다.
    /// 기기 시계가 뒤로 가는 등으로 종료가 시작보다 앞서도 **음수가 되지 않는다.**
    init(
        id: String = UUID().uuidString,
        planID: String,
        startedAt: Date,
        endedAt: Date,
        plannedDurationMinutes: Int,
        restType: RestType,
        audio: AudioMode,
        movement: MovementType,
        outcome: Outcome,
        feedback: RestFeedback? = nil
    ) {
        self.id = id
        self.planID = planID
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.plannedDurationMinutes = plannedDurationMinutes
        self.actualDurationSeconds = Self.elapsedSeconds(from: startedAt, to: endedAt)
        self.restType = restType
        self.audio = audio
        self.movement = movement
        self.outcome = outcome
        self.feedback = feedback
    }

    /// 경과 시간을 초로 계산한다. 0 미만으로 내려가지 않는다.
    static func elapsedSeconds(from start: Date, to end: Date) -> Int {
        let interval = end.timeIntervalSince(start)
        guard interval.isFinite, interval > 0 else { return 0 }
        return Int(interval.rounded())
    }

    /// 같은 값에 응답만 채워 넣은 사본.
    ///
    /// 결과 화면에서 사용자가 고른 뒤 **한 번만** 저장하기 위해 쓴다.
    /// 세션이 끝날 때 기록을 만들어 두고, 응답이 정해지면 여기서 채워
    /// 저장소에 한 번 넘긴다. 저장 후 수정하는 API 를 두지 않는다.
    func withFeedback(_ feedback: RestFeedback?) -> RestHistoryEntry {
        RestHistoryEntry(
            id: id,
            planID: planID,
            startedAt: startedAt,
            endedAt: endedAt,
            plannedDurationMinutes: plannedDurationMinutes,
            restType: restType,
            audio: audio,
            movement: movement,
            outcome: outcome,
            feedback: feedback
        )
    }
}
