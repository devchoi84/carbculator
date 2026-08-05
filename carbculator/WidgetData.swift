//
//  WidgetData.swift
//  carbculator
//
//  위젯(별도 익스텐션)과 공유하는 데이터. App Group의 공유 UserDefaults에 기록한다.
//
//  ⚠️ 위젯이 동작하려면 앱·위젯 두 타깃 모두 App Groups 기능에
//     "group.dev-choi.carbculator" 를 추가해야 한다. (Xcode Signing & Capabilities)
//     App Group이 아직 없으면 아래 쓰기는 조용히 무시되어 앱에는 영향이 없다.
//

import Foundation
import WidgetKit

enum WidgetData {
    /// 앱·위젯이 공유하는 App Group 식별자
    static let appGroup = "group.dev-choi.carbculator"

    enum Key {
        static let icr = "widget.icr"
        static let foods = "widget.foods"
        static let insulin = "widget.insulin"
        static let date = "widget.date"
    }

    private static var shared: UserDefaults? { UserDefaults(suiteName: appGroup) }

    /// 탄수화물 계수(ICR)만 갱신
    static func updateICR(_ icr: Double) {
        guard let d = shared else { return }
        d.set(icr, forKey: Key.icr)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// 최근 계산 결과(식사·인슐린)와 ICR을 함께 갱신
    static func updateLatest(icr: Double, foods: [String], insulin: Double, date: Date = Date()) {
        guard let d = shared else { return }
        d.set(icr, forKey: Key.icr)
        d.set(foods, forKey: Key.foods)
        d.set(insulin, forKey: Key.insulin)
        d.set(date, forKey: Key.date)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
