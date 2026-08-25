//
//  RestHistoryStore.swift
//  Shim
//
//  쉼 기록의 로컬 저장소.
//
//  docs/IOS_SPEC.md §3 — 초기 PoC 는 UserDefaults 또는 경량 로컬 저장소.
//
//  ── 저장 실패는 쉼을 방해하지 않는다 (Sprint 7 요구 7) ────────────────
//
//  `save` 는 throw 하지 않는다. 저장에 실패해도 사용자는 이미 쉼을 마쳤고,
//  기록이 남지 않았다는 이유로 흐름을 멈추거나 오류를 띄우는 것은
//  제품 경험상 손해다. 실패는 조용히 넘긴다.
//
//  읽기도 마찬가지다. 저장된 데이터가 손상됐으면 빈 기록으로 취급한다.
//  앱이 죽지 않는다.
//
//  ── 보관 정책 ────────────────────────────────────────────────────────
//
//  최근 50건만 남긴다. docs/PRODUCT.md §12 — 필요한 최소 데이터만 수집한다.
//  무한히 쌓이면 저장소도 커지고 보관 범위도 흐려진다.
//
//  이 파일은 UI 를 알지 못한다. SwiftUI·UIKit 을 import 하지 않는다.
//

import Foundation

@MainActor
protocol RestHistoryStore: AnyObject {
    /// 기록을 저장한다. 실패해도 throw 하지 않는다.
    func save(_ entry: RestHistoryEntry)

    /// 최근 기록을 최신순으로 돌려준다.
    func recentEntries(limit: Int) -> [RestHistoryEntry]

    /// 모든 기록을 지운다.
    ///
    /// docs/PRODUCT.md §12 — "사용자가 자신의 기록을 확인하고 삭제할 수 있는
    /// 구조를 향후 제공한다." 화면은 아직 없지만 경로는 열어 둔다.
    func removeAll()
}

extension RestHistoryStore {
    /// 기본 조회 개수.
    func recentEntries() -> [RestHistoryEntry] {
        recentEntries(limit: UserDefaultsRestHistoryStore.maxEntries)
    }
}

@MainActor
final class UserDefaultsRestHistoryStore: RestHistoryStore {

    /// 보관하는 최대 기록 수.
    static let maxEntries = 50

    /// 저장 키. 스키마가 바뀌면 뒤의 버전을 올리고 이전 키는 무시한다.
    static let storageKey = "rest_history_v1"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    // MARK: - RestHistoryStore

    func save(_ entry: RestHistoryEntry) {
        var entries = loadEntries()
        entries.insert(entry, at: 0)   // 최신이 앞
        if entries.count > Self.maxEntries {
            entries = Array(entries.prefix(Self.maxEntries))
        }
        persist(entries)
    }

    func recentEntries(limit: Int) -> [RestHistoryEntry] {
        guard limit > 0 else { return [] }
        return Array(loadEntries().prefix(limit))
    }

    func removeAll() {
        defaults.removeObject(forKey: Self.storageKey)
    }

    // MARK: - 내부

    /// 저장된 기록을 읽는다. 없거나 손상됐으면 빈 배열이다.
    private func loadEntries() -> [RestHistoryEntry] {
        guard let data = defaults.data(forKey: Self.storageKey) else { return [] }
        do {
            return try Self.decoder.decode([RestHistoryEntry].self, from: data)
        } catch {
            // 손상된 데이터로 앱이 죽지 않는다. 기록이 없는 것으로 본다.
            return []
        }
    }

    private func persist(_ entries: [RestHistoryEntry]) {
        do {
            let data = try Self.encoder.encode(entries)
            defaults.set(data, forKey: Self.storageKey)
        } catch {
            // 저장 실패가 사용자의 쉼 흐름을 막지 않는다. 조용히 넘긴다.
        }
    }
}
