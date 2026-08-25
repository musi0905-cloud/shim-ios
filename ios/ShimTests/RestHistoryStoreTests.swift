//
//  RestHistoryStoreTests.swift
//  ShimTests
//
//  Sprint 7 — 쉼 기록의 저장 계약을 고정한다.
//
//  특히 두 가지를 지킨다.
//    1. 프라이버시 — 자유 텍스트 원문을 담을 필드가 존재하지 않는다
//    2. 저장 실패나 손상 데이터가 앱을 죽이지 않는다
//

import XCTest
@testable import Shim

@MainActor
final class RestHistoryEntryTests: XCTestCase {

    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func entry(
        startedAt: Date? = nil,
        endedAt: Date? = nil,
        outcome: RestHistoryEntry.Outcome = .completed,
        feedback: RestFeedback? = nil
    ) -> RestHistoryEntry {
        RestHistoryEntry(
            id: "entry-1",
            planID: "mock-001",
            startedAt: startedAt ?? start,
            endedAt: endedAt ?? start.addingTimeInterval(600),
            plannedDurationMinutes: 10,
            restType: .environmentReset,
            audio: .calmAcoustic,
            movement: .slowWalk,
            outcome: outcome,
            feedback: feedback
        )
    }

    // MARK: - 실제 지속시간

    func testActualDurationIsComputedFromTimestamps() {
        XCTAssertEqual(entry().actualDurationSeconds, 600)
    }

    /// 계획 10분을 2분 만에 그만둔 기록.
    func testShortCancelRecordsActualDuration() {
        let e = entry(endedAt: start.addingTimeInterval(120), outcome: .cancelled)

        XCTAssertEqual(e.plannedDurationMinutes, 10, "계획은 그대로 남는다")
        XCTAssertEqual(e.actualDurationSeconds, 120, "실제 지속시간이 따로 남는다")
        XCTAssertEqual(e.outcome, .cancelled)
    }

    /// 거의 끝까지 간 취소와 바로 그만둔 취소가 구분되어야 한다.
    func testLateCancelIsDistinguishableFromEarlyCancel() {
        let early = entry(endedAt: start.addingTimeInterval(120), outcome: .cancelled)
        let late = entry(endedAt: start.addingTimeInterval(590), outcome: .cancelled)

        XCTAssertNotEqual(early.actualDurationSeconds, late.actualDurationSeconds)
        XCTAssertEqual(late.actualDurationSeconds, 590)
    }

    /// 기기 시계가 뒤로 가도 음수가 되지 않아야 한다.
    func testActualDurationNeverGoesNegative() {
        let e = entry(endedAt: start.addingTimeInterval(-300))
        XCTAssertEqual(e.actualDurationSeconds, 0)
    }

    func testActualDurationIsZeroWhenStartAndEndMatch() {
        XCTAssertEqual(entry(endedAt: start).actualDurationSeconds, 0)
    }

    // MARK: - Codable

    func testRoundTripPreservesValues() throws {
        let original = entry(outcome: .completed, feedback: .better)
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode(
            RestHistoryEntry.self, from: encoder.encode(original)
        )
        XCTAssertEqual(decoded, original)
    }

    func testFeedbackCanBeAbsent() throws {
        let original = entry(feedback: nil)
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode(
            RestHistoryEntry.self, from: encoder.encode(original)
        )
        XCTAssertNil(decoded.feedback)
    }

    func testWithFeedbackOnlyChangesFeedback() {
        let base = entry(feedback: nil)
        let updated = base.withFeedback(.worse)

        XCTAssertEqual(updated.feedback, .worse)
        XCTAssertEqual(updated.id, base.id)
        XCTAssertEqual(updated.planID, base.planID)
        XCTAssertEqual(updated.actualDurationSeconds, base.actualDurationSeconds)
        XCTAssertEqual(updated.outcome, base.outcome)
    }

    // MARK: - 프라이버시 (Sprint 7 요구 5)

    /// 인코딩된 키가 허용된 집합과 정확히 일치해야 한다.
    ///
    /// 누군가 자유 텍스트 필드를 추가하면 이 테스트가 깨진다.
    /// "저장하지 않는다" 가 아니라 "저장할 자리가 없다" 로 프라이버시를 지킨다.
    func testEncodedKeysAreExactlyTheAllowedSet() throws {
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoder.encode(entry(feedback: .same)))
                as? [String: Any]
        )

        let allowed: Set<String> = [
            "id", "plan_id", "started_at", "ended_at",
            "planned_duration_minutes", "actual_duration_seconds",
            "rest_type", "audio", "movement", "outcome", "feedback",
        ]

        XCTAssertEqual(Set(object.keys), allowed,
                       "허용되지 않은 필드가 저장되고 있다: \(Set(object.keys).subtracting(allowed))")
    }

    /// 자유 텍스트로 보이는 키가 하나도 없어야 한다.
    func testNoFreeTextFieldExists() throws {
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoder.encode(entry()))
                as? [String: Any]
        )

        for forbidden in ["note", "notes", "text", "input", "message",
                          "user_input", "free_text", "comment", "guidance_messages"] {
            XCTAssertNil(object[forbidden], "자유 텍스트 필드 '\(forbidden)' 가 있으면 안 된다")
        }
    }
}

@MainActor
final class UserDefaultsRestHistoryStoreTests: XCTestCase {

    private var defaults: UserDefaults!
    private var store: UserDefaultsRestHistoryStore!

    override func setUp() async throws {
        try await super.setUp()
        defaults = TestDefaults.make("history")
        store = UserDefaultsRestHistoryStore(defaults: defaults)
    }

    override func tearDown() async throws {
        store = nil
        defaults = nil
        try await super.tearDown()
    }

    private func entry(id: String, minutesAgo: Int = 0) -> RestHistoryEntry {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
            .addingTimeInterval(TimeInterval(-minutesAgo * 60))
        return RestHistoryEntry(
            id: id,
            planID: "plan-\(id)",
            startedAt: start,
            endedAt: start.addingTimeInterval(600),
            plannedDurationMinutes: 10,
            restType: .environmentReset,
            audio: .calmAcoustic,
            movement: .slowWalk,
            outcome: .completed,
            feedback: .better
        )
    }

    // MARK: - 기본 동작

    func testEmptyStoreReturnsNothing() {
        XCTAssertTrue(store.recentEntries().isEmpty)
    }

    func testSavedEntryCanBeRead() {
        store.save(entry(id: "a"))

        let entries = store.recentEntries()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.id, "a")
        XCTAssertEqual(entries.first?.feedback, .better)
    }

    /// 최신 기록이 앞에 와야 한다.
    func testEntriesAreReturnedNewestFirst() {
        store.save(entry(id: "first"))
        store.save(entry(id: "second"))
        store.save(entry(id: "third"))

        XCTAssertEqual(store.recentEntries().map(\.id), ["third", "second", "first"])
    }

    func testLimitIsRespected() {
        for index in 0..<5 { store.save(entry(id: "\(index)")) }

        XCTAssertEqual(store.recentEntries(limit: 2).count, 2)
        XCTAssertEqual(store.recentEntries(limit: 0).count, 0)
        XCTAssertEqual(store.recentEntries(limit: 99).count, 5)
    }

    // MARK: - 앱 재실행 (AC-3)

    /// 같은 저장소를 읽는 **새 인스턴스**가 기존 기록을 봐야 한다.
    ///
    /// ⚠️ 이것은 실제 프로세스 종료 후 재실행이 아니다. UserDefaults 에
    ///    실제로 기록됐는지를 확인하는 강한 근거이지 동일한 검증은 아니다.
    func testNewStoreInstanceSeesPersistedEntries() {
        store.save(entry(id: "persisted"))

        let freshStore = UserDefaultsRestHistoryStore(defaults: defaults)

        XCTAssertEqual(freshStore.recentEntries().map(\.id), ["persisted"])
    }

    // MARK: - 보관 정책 (Sprint 7 요구 6)

    func testOldestEntriesAreDroppedBeyondLimit() {
        let cap = UserDefaultsRestHistoryStore.maxEntries
        for index in 0..<(cap + 10) { store.save(entry(id: "\(index)")) }

        let entries = store.recentEntries(limit: cap + 100)
        XCTAssertEqual(entries.count, cap, "최근 \(cap)건만 남는다")
        XCTAssertEqual(entries.first?.id, "\(cap + 9)", "가장 최근 기록이 남아야 한다")
        XCTAssertFalse(entries.contains { $0.id == "0" }, "가장 오래된 기록은 밀려난다")
    }

    // MARK: - 손상 데이터 (Sprint 7 요구 7)

    /// 저장된 값이 JSON 이 아니어도 크래시하지 않아야 한다.
    func testCorruptedDataIsTreatedAsEmpty() {
        defaults.set(Data("이건 JSON 이 아니다".utf8),
                     forKey: UserDefaultsRestHistoryStore.storageKey)

        XCTAssertTrue(store.recentEntries().isEmpty, "빈 기록으로 취급한다")
    }

    /// 손상된 뒤에도 새 기록을 저장할 수 있어야 한다.
    func testCanSaveAfterCorruption() {
        defaults.set(Data([0x00, 0x01, 0x02]),
                     forKey: UserDefaultsRestHistoryStore.storageKey)

        store.save(entry(id: "recovered"))

        XCTAssertEqual(store.recentEntries().map(\.id), ["recovered"])
    }

    func testWrongTypeInStorageIsTreatedAsEmpty() {
        defaults.set("문자열", forKey: UserDefaultsRestHistoryStore.storageKey)
        XCTAssertTrue(store.recentEntries().isEmpty)
    }

    // MARK: - 삭제

    func testRemoveAllClearsEntries() {
        store.save(entry(id: "a"))
        store.save(entry(id: "b"))

        store.removeAll()

        XCTAssertTrue(store.recentEntries().isEmpty)
        XCTAssertTrue(
            UserDefaultsRestHistoryStore(defaults: defaults).recentEntries().isEmpty,
            "새 인스턴스에서도 지워져 있어야 한다"
        )
    }
}
