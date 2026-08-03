//
//  InsulinCalculator.swift
//  carbculator
//

import Foundation

// MARK: - 설정 저장 키

enum SettingsKeys {
    static let icr = "settings.icr"
    static let isf = "settings.isf"
    static let targetBG = "settings.targetBG"
    static let penIncrement = "settings.penIncrement"
    static let correctionEnabled = "settings.correctionEnabled"
    static let isOnboarded = "settings.isOnboarded"
    static let disclaimerHidden = "settings.disclaimerHidden"
}

// MARK: - 음식 종류

/// 주식별 탄수화물 비율 (식약처 식품영양성분 DB 기반 근사치)
enum FoodType: String, CaseIterable, Identifiable {
    case whiteRice = "쌀밥 (백미)"
    case mixedGrainRice = "잡곡밥"
    case brownRice = "현미밥"
    case bread = "식빵"
    case sweetPotato = "고구마 (삶은 것)"
    case potato = "감자 (삶은 것)"

    var id: String { rawValue }

    /// 100g당 탄수화물(g)
    var carbsPer100g: Double {
        switch self {
        case .whiteRice: return 33
        case .mixedGrainRice: return 30
        case .brownRice: return 30
        case .bread: return 50
        case .sweetPotato: return 30
        case .potato: return 17
        }
    }
}

// MARK: - 계산 결과

struct BolusResult {
    /// 섭취 탄수화물(g)
    let carbs: Double
    /// 식사 인슐린 = 탄수화물 ÷ ICR
    let mealBolus: Double
    /// 교정 인슐린 = (현재 혈당 − 목표 혈당) ÷ ISF. 혈당이 목표보다 낮으면 음수.
    let correctionBolus: Double
    /// 음수 방지 처리 후, 펜 단위 반영 전 계산값
    let totalRaw: Double
    /// 펜 단위로 내림 처리한 최종 권장량
    let totalRounded: Double
}

// MARK: - 계산 엔진

enum InsulinCalculator {
    /// 이 값 이하의 혈당에서는 계산을 중단하고 저혈당 경고를 표시한다
    static let hypoThresholdBG: Double = 70

    /// 음식 무게(g)를 탄수화물(g)로 변환
    static func carbs(foodWeight: Double, food: FoodType) -> Double {
        foodWeight * food.carbsPer100g / 100
    }

    /// 최종 권장 인슐린 계산. ICR/펜 단위(교정 사용 시 ISF 포함)가 유효하지 않으면 nil.
    /// `correctionEnabled`가 false면 ISF 없이 식사 인슐린만 계산한다.
    static func calculate(
        carbs: Double,
        currentBG: Double,
        targetBG: Double,
        icr: Double,
        isf: Double,
        penIncrement: Double,
        correctionEnabled: Bool = true
    ) -> BolusResult? {
        guard icr > 0, penIncrement > 0 else { return nil }
        guard !correctionEnabled || isf > 0 else { return nil }

        let mealBolus = carbs / icr
        let correctionBolus = correctionEnabled ? (currentBG - targetBG) / isf : 0
        // 혈당이 목표보다 낮으면 교정값이 음수가 되어 식사 인슐린에서 차감된다.
        // 전체가 음수면 0으로 처리해 저혈당을 방지한다.
        let totalRaw = max(0, mealBolus + correctionBolus)
        // 저혈당 방지를 위해 반올림 대신 펜 단위 내림 처리
        let totalRounded = (totalRaw / penIncrement).rounded(.down) * penIncrement

        return BolusResult(
            carbs: carbs,
            mealBolus: mealBolus,
            correctionBolus: correctionBolus,
            totalRaw: totalRaw,
            totalRounded: totalRounded
        )
    }
}

// MARK: - 입력 파싱 / 표시 형식

extension String {
    /// 쉼표 소수점 입력을 허용하는 Double 파싱 ("5,5" → 5.5)
    var parsedDouble: Double? {
        Double(trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
    }
}

extension Double {
    /// 소수점 최대 2자리 표시
    var display: String {
        formatted(.number.precision(.fractionLength(0...2)))
    }

    /// 소수점 최대 1자리 표시
    var display1: String {
        formatted(.number.precision(.fractionLength(0...1)))
    }
}
