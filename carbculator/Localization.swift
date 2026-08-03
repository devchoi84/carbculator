//
//  Localization.swift
//  carbculator
//

import Foundation

/// 앱 내에서 전환 가능한 표시 언어. 시스템 언어와 별개로 동작한다.
enum AppLanguage: String, CaseIterable, Identifiable {
    case korean = "ko"
    case english = "en"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .korean: return "한국어"
        case .english: return "English"
        }
    }

    /// 현재 언어에 맞는 문자열을 선택한다
    func t(_ ko: String, _ en: String) -> String {
        self == .korean ? ko : en
    }
}

extension SettingsKeys {
    static let language = "settings.language"
}

extension FoodType {
    /// 언어별 표시 이름 (rawValue는 저장/식별용으로 유지)
    func name(_ lang: AppLanguage) -> String {
        switch self {
        case .whiteRice: return lang.t("쌀밥 (백미)", "White rice")
        case .mixedGrainRice: return lang.t("잡곡밥", "Multigrain rice")
        case .brownRice: return lang.t("현미밥", "Brown rice")
        case .bread: return lang.t("식빵", "White bread")
        case .sweetPotato: return lang.t("고구마 (삶은 것)", "Sweet potato (boiled)")
        case .potato: return lang.t("감자 (삶은 것)", "Potato (boiled)")
        }
    }
}
