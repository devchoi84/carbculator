//
//  ICREditView.swift
//  carbculator
//

import SwiftUI

/// 설정에서 진입하는 탄수화물 계수(ICR) 수정 페이지.
/// 온보딩과 동일한 계산 방식(직접 입력 / 밥 양 / 처방 기준 / TDD 추정)을 지원하며,
/// 저장 버튼을 눌러야 기존 계수를 덮어쓴다.
struct ICREditView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKeys.icr) private var storedICR = 0.0
    @AppStorage(SettingsKeys.language) private var languageRaw = AppLanguage.korean.rawValue

    private enum Method: CaseIterable, Identifiable {
        case direct
        case meal
        case prescription
        case tdd
        var id: Self { self }
    }

    @State private var method: Method = .direct
    @State private var icrText = ""
    @State private var mealFood: FoodType = .whiteRice
    @State private var mealWeightText = ""
    @State private var mealUnitsText = ""
    @State private var carbsText = ""
    @State private var unitsText = ""
    @State private var tddText = ""

    private var lang: AppLanguage { AppLanguage(rawValue: languageRaw) ?? .korean }

    var body: some View {
        Form {
            Section(lang.t("현재 저장된 계수", "Current ratio")) {
                LabeledContent(lang.t("탄수화물 계수", "Carb ratio"),
                               value: "\(storedICR.display1) g/U")
            }

            Section(lang.t("계산 방식", "Method")) {
                Picker(lang.t("계산 방식", "Method"), selection: $method) {
                    ForEach(Method.allCases) { m in
                        Text(methodLabel(m)).tag(m)
                    }
                }
                .pickerStyle(.menu)
            }

            inputSection

            if let icr = newICR {
                Section {
                    LabeledContent(lang.t("새 계수", "New ratio")) {
                        Text("\(icr.display1) g/U")
                            .font(.headline)
                            .foregroundStyle(.blue)
                    }
                }
            }

            Section {
                Button(lang.t("저장", "Save")) { save() }
                    .disabled(newICR == nil)
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(lang.t("역산/추정으로 구한 계수는 시작점입니다. 식후 혈당 반응을 보며 담당 의료진과 함께 조정하세요.",
                                "A recalculated or estimated ratio is a starting point. Adjust it with your care team based on your post-meal glucose."))
                    SourceLink(label: lang.t("출처: UCSF 당뇨 교육센터 (탄수화물 계수·500의 법칙)",
                                             "Source: UCSF Diabetes Teaching Center (carb ratio · 500 rule)"),
                               url: MedicalSources.insulinDoseCalc)
                }
            }
        }
        .navigationTitle(lang.t("탄수화물 계수 수정", "Edit carb ratio"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(lang.t("완료", "Done")) { hideKeyboard() }
            }
        }
        .onAppear {
            if storedICR > 0, icrText.isEmpty {
                icrText = storedICR.display1
            }
        }
    }

    private func methodLabel(_ m: Method) -> String {
        switch m {
        case .direct: return lang.t("직접 입력", "Enter directly")
        case .meal: return lang.t("밥 양으로 계산", "From my usual meal")
        case .prescription: return lang.t("처방 기준으로 계산", "From doctor's guidance")
        case .tdd: return lang.t("하루 총 인슐린으로 추정", "From total daily insulin")
        }
    }

    // MARK: - 방식별 입력 폼

    @ViewBuilder
    private var inputSection: some View {
        switch method {
        case .direct:
            Section(lang.t("계수 입력", "Enter ratio")) {
                HStack {
                    TextField(lang.t("탄수화물 계수", "Carb ratio"), text: $icrText)
                        .keyboardType(.decimalPad)
                    Text("g/U")
                        .foregroundStyle(.secondary)
                }
            }
        case .meal:
            Section {
                Picker(lang.t("주식 종류", "Staple food"), selection: $mealFood) {
                    ForEach(FoodType.allCases) { food in
                        Text(food.name(lang)).tag(food)
                    }
                }
                HStack {
                    TextField(lang.t("평소 먹는 밥 양", "Usual food amount"), text: $mealWeightText)
                        .keyboardType(.decimalPad)
                    Text("g")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    TextField(lang.t("그때 주사하는 인슐린", "Insulin for that meal"), text: $mealUnitsText)
                        .keyboardType(.decimalPad)
                    Text("U")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(lang.t("평소 식사 기준", "Usual meal basis"))
            } footer: {
                if let weight = mealWeightText.parsedDouble, weight > 0 {
                    Text(lang.t("탄수화물 약 \(InsulinCalculator.carbs(foodWeight: weight, food: mealFood).display1) g",
                                "≈ \(InsulinCalculator.carbs(foodWeight: weight, food: mealFood).display1) g of carbs"))
                }
            }
        case .prescription:
            Section {
                HStack {
                    TextField(lang.t("먹는 탄수화물", "Carbs eaten"), text: $carbsText)
                        .keyboardType(.decimalPad)
                    Text("g")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    TextField(lang.t("주사하는 인슐린", "Insulin injected"), text: $unitsText)
                        .keyboardType(.decimalPad)
                    Text("U")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(lang.t("병원 처방 기준", "Doctor's guidance"))
            } footer: {
                Text(lang.t("예: “탄수화물 60g 먹을 때 6단위 주사”",
                            "e.g. “6 units for 60g of carbs”"))
            }
        case .tdd:
            Section {
                HStack {
                    TextField(lang.t("하루 총 인슐린", "Total daily insulin"), text: $tddText)
                        .keyboardType(.decimalPad)
                    Text("U")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(lang.t("하루 총 인슐린 (TDD)", "Total daily insulin (TDD)"))
            } footer: {
                Text(lang.t("기초 + 식사 인슐린을 더한 하루 평균 총량입니다. 500의 법칙으로 추정합니다.",
                            "Your average daily total of basal plus meal insulin. Estimated with the 500 rule."))
            }
        }
    }

    // MARK: - 계산 / 저장

    private var newICR: Double? {
        switch method {
        case .direct:
            guard let v = icrText.parsedDouble, v > 0 else { return nil }
            return v
        case .meal:
            guard let weight = mealWeightText.parsedDouble, let units = mealUnitsText.parsedDouble,
                  weight > 0, units > 0 else { return nil }
            return InsulinCalculator.carbs(foodWeight: weight, food: mealFood) / units
        case .prescription:
            guard let carbs = carbsText.parsedDouble, let units = unitsText.parsedDouble,
                  carbs > 0, units > 0 else { return nil }
            return carbs / units
        case .tdd:
            guard let tdd = tddText.parsedDouble, tdd > 0 else { return nil }
            return 500 / tdd
        }
    }

    private func save() {
        guard let icr = newICR else { return }
        storedICR = icr
        dismiss()
    }
}

#Preview {
    NavigationStack {
        ICREditView()
    }
}
