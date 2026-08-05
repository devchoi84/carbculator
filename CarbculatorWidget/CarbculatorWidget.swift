//
//  CarbculatorWidget.swift
//  CarbculatorWidget
//
//  small: 탄수화물 계수(ICR)를 숫자로 표시
//  medium: 최근 식사 메뉴와 계산된 인슐린을 표시
//
//  데이터는 App Group("group.dev-choi.carbculator")의 공유 UserDefaults에서 읽는다.
//  앱이 계산/설정 변경 시 값을 기록하고 WidgetCenter로 새로고침한다.
//

import WidgetKit
import SwiftUI

// MARK: - 공유 데이터

private enum Shared {
    static let appGroup = "group.dev-choi.carbculator"
    static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }
}

private func fmt(_ value: Double, _ digits: Int = 1) -> String {
    String(format: "%.\(digits)f", value)
}

// MARK: - 타임라인 엔트리

struct CarbEntry: TimelineEntry {
    let date: Date
    let icr: Double
    let foods: [String]
    let insulin: Double
    let mealDate: Date?

    static let sample = CarbEntry(
        date: Date(),
        icr: 10.0,
        foods: ["순대국밥 250g", "김치 30g"],
        insulin: 6.0,
        mealDate: Date()
    )
}

// MARK: - Provider

struct CarbProvider: TimelineProvider {
    func placeholder(in context: Context) -> CarbEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (CarbEntry) -> Void) {
        completion(context.isPreview ? .sample : load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CarbEntry>) -> Void) {
        // 앱이 값 갱신 시 WidgetCenter로 새로고침하므로 자동 만료는 두지 않는다.
        completion(Timeline(entries: [load()], policy: .never))
    }

    private func load() -> CarbEntry {
        let d = Shared.defaults
        return CarbEntry(
            date: Date(),
            icr: d?.double(forKey: "widget.icr") ?? 0,
            foods: d?.stringArray(forKey: "widget.foods") ?? [],
            insulin: d?.double(forKey: "widget.insulin") ?? 0,
            mealDate: d?.object(forKey: "widget.date") as? Date
        )
    }
}

// MARK: - 위젯 정의

struct CarbculatorWidget: Widget {
    let kind = "CarbculatorWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CarbProvider()) { entry in
            CarbculatorWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color(.systemBackground) }
        }
        .configurationDisplayName("Carbculator")
        .description("탄수화물 계수와 최근 식사·인슐린을 확인하세요.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - 뷰

struct CarbculatorWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CarbEntry

    var body: some View {
        switch family {
        case .systemSmall: smallView
        default: mediumView
        }
    }

    // small: 탄수화물 계수(ICR)
    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("탄수화물 계수", systemImage: "drop.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            if entry.icr > 0 {
                Text(fmt(entry.icr))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.blue)
                    .minimumScaleFactor(0.5)
                Text("g/U")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("설정 필요")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // medium: 최근 식사 + 인슐린
    private var mediumView: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Label("최근 식사", systemImage: "fork.knife")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if entry.foods.isEmpty {
                    Text("최근 계산 내역이 없습니다")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text(entry.foods.joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                }
                Spacer()
                if let date = entry.mealDate {
                    Text(date, format: .dateTime.month().day().hour().minute())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 2) {
                Text("권장 인슐린")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(fmt(entry.insulin, entry.insulin == entry.insulin.rounded() ? 0 : 1)) U")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.blue)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - 미리보기

#Preview(as: .systemSmall) {
    CarbculatorWidget()
} timeline: {
    CarbEntry.sample
}

#Preview(as: .systemMedium) {
    CarbculatorWidget()
} timeline: {
    CarbEntry.sample
}
