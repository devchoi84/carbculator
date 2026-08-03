//
//  MealHistory.swift
//  carbculator
//
//  식사·인슐린 계산 내역을 최근 7일간 로컬(UserDefaults)에 보관한다.
//

import Foundation

// MARK: - 내역 레코드

/// 한 번의 계산 결과 요약. (상세 수치 대신 목록 표시에 필요한 값만 저장)
struct MealRecord: Codable, Identifiable {
    let id: UUID
    let date: Date
    /// 표시용 음식 항목 (예: "순대국밥 250g"). 직접 입력이면 빈 배열일 수 있음.
    let foods: [String]
    /// 섭취 탄수화물(g)
    let carbs: Double
    /// 권장 인슐린(U) — 펜 단위 내림 적용된 최종값
    let insulin: Double

    init(id: UUID = UUID(), date: Date = Date(), foods: [String], carbs: Double, insulin: Double) {
        self.id = id
        self.date = date
        self.foods = foods
        self.carbs = carbs
        self.insulin = insulin
    }
}

// MARK: - 저장소

enum MealHistoryStore {
    private static let key = "history.records"
    /// 보관 기간(일)
    private static let retentionDays = 7

    /// 저장된 내역을 최신순으로 반환한다. (읽을 때 만료분 정리)
    static func load() -> [MealRecord] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let records = try? JSONDecoder().decode([MealRecord].self, from: data) else {
            return []
        }
        let valid = prune(records)
        if valid.count != records.count { save(valid) }
        return valid.sorted { $0.date > $1.date }
    }

    /// 새 내역을 추가하고 만료분을 정리해 저장한다.
    static func add(_ record: MealRecord) {
        var records = load()
        records.append(record)
        save(prune(records))
    }

    /// 전체 삭제
    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    // MARK: - 내부

    private static func prune(_ records: [MealRecord]) -> [MealRecord] {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) else {
            return records
        }
        return records.filter { $0.date >= cutoff }
    }

    private static func save(_ records: [MealRecord]) {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
