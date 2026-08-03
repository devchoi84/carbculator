//
//  HistoryView.swift
//  carbculator
//
//  최근 7일간의 식사·인슐린 계산 내역 목록.
//

import SwiftUI

struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKeys.language) private var languageRaw = AppLanguage.korean.rawValue

    @State private var records: [MealRecord] = []

    private var lang: AppLanguage { AppLanguage(rawValue: languageRaw) ?? .korean }

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    ContentUnavailableView(
                        lang.t("저장된 내역이 없습니다", "No history yet"),
                        systemImage: "clock",
                        description: Text(lang.t("계산을 완료하면 최근 7일간의 내역이 여기에 표시됩니다.",
                                                 "Completed calculations from the last 7 days appear here."))
                    )
                } else {
                    List {
                        Section {
                            ForEach(records) { record in
                                row(record)
                            }
                        } footer: {
                            Text(lang.t("내역은 최근 7일간만 보관되며 이후 자동으로 삭제됩니다.",
                                        "History is kept for 7 days and then removed automatically."))
                        }
                    }
                }
            }
            .navigationTitle(lang.t("산출 내역", "History"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(lang.t("완료", "Done")) { dismiss() }
                }
            }
            .onAppear { records = MealHistoryStore.load() }
        }
    }

    private func row(_ record: MealRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(record.date, format: .dateTime.month().day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(record.insulin.display) U")
                    .font(.headline)
                    .foregroundStyle(.blue)
            }
            Text(foodSummary(record))
                .font(.subheadline)
                .foregroundStyle(.primary)
            Text(lang.t("탄수화물 \(record.carbs.display1) g", "Carbs \(record.carbs.display1) g"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func foodSummary(_ record: MealRecord) -> String {
        record.foods.isEmpty
            ? lang.t("탄수화물 직접 입력", "Carbs entered directly")
            : record.foods.joined(separator: ", ")
    }
}

#Preview {
    HistoryView()
}
