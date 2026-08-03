//
//  CalculatorView.swift
//  carbculator
//

import SwiftUI

/// 식사 시마다 사용하는 메인 계산 플로우.
/// 현재 혈당 → 식사량 → 결과 순서로 한 페이지씩 부드럽게 전환된다.
struct CalculatorView: View {
    private enum Step: Int {
        case bloodGlucose
        case hypoWarning
        case meal
        case result
    }

    private enum MealInputMode: CaseIterable, Identifiable {
        case food
        case carbs
        var id: Self { self }
    }

    @AppStorage(SettingsKeys.icr) private var icr = 0.0
    @AppStorage(SettingsKeys.isf) private var isf = 0.0
    @AppStorage(SettingsKeys.targetBG) private var targetBG = 110.0
    @AppStorage(SettingsKeys.penIncrement) private var penIncrement = 1.0
    @AppStorage(SettingsKeys.correctionEnabled) private var correctionEnabled = true
    @AppStorage(SettingsKeys.language) private var languageRaw = AppLanguage.korean.rawValue

    @State private var step: Step = .bloodGlucose
    @State private var isForward = true
    @State private var showSettings = false

    // 입력값
    @State private var bgText = ""
    @State private var inputMode: MealInputMode = .food
    @State private var selectedFood: FoodType = .whiteRice
    @State private var weightText = ""
    @State private var carbsText = ""

    private var lang: AppLanguage { AppLanguage(rawValue: languageRaw) ?? .korean }

    var body: some View {
        NavigationStack {
            ZStack {
                stepContent
                    .id(step)
                    .transition(.stepPush(forward: isForward))
            }
            .navigationTitle("Carbculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    backButton
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(lang.t("완료", "Done")) { hideKeyboard() }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }

    // MARK: - 단계별 페이지

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .bloodGlucose: bloodGlucosePage
        case .hypoWarning: hypoWarningPage
        case .meal: mealPage
        case .result: resultPage
        }
    }

    @ViewBuilder
    private var backButton: some View {
        switch step {
        case .meal:
            Button { goBack(to: .bloodGlucose) } label: { Image(systemName: "chevron.left") }
        case .result:
            Button { goBack(to: .meal) } label: { Image(systemName: "chevron.left") }
        default:
            EmptyView()
        }
    }

    // MARK: 1) 현재 혈당

    private var bloodGlucosePage: some View {
        StepPage(
            title: lang.t("현재 혈당을 입력하세요", "Enter your current blood glucose"),
            subtitle: lang.t("식사 직전에 측정한 혈당 수치(mg/dL)입니다.",
                             "Measured just before your meal (mg/dL)."),
            nextTitle: lang.t("다음", "Next"),
            isNextEnabled: bgValue != nil,
            onNext: {
                guard let bg = bgValue else { return }
                if bg <= InsulinCalculator.hypoThresholdBG {
                    advance(to: .hypoWarning)
                } else {
                    advance(to: .meal)
                }
            }
        ) {
            VStack(alignment: .leading, spacing: 12) {
                NumberInputField(placeholder: lang.t("혈당", "Blood glucose"),
                                 unit: "mg/dL", text: $bgText)
                if let v = bgText.parsedDouble, !(20...600).contains(v) {
                    Text(lang.t("혈당 수치를 다시 확인해 주세요. (20~600 mg/dL)",
                                "Please double-check the value. (20–600 mg/dL)"))
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: 2) 저혈당 경고 (혈당 70 이하 시 계산 차단)

    private var hypoWarningPage: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.red)
            Text(lang.t("저혈당 위험", "Low Blood Glucose"))
                .font(.title.bold())
            Text(lang.t("현재 혈당이 \(InsulinCalculator.hypoThresholdBG.display) mg/dL 이하입니다.\n인슐린 계산을 중단하세요.\n\n즉시 단순당 15~20g을 섭취하세요.\n(주스 반 컵, 사탕 3~4개, 설탕물 등)\n\n15분 후 혈당을 다시 측정해 주세요.",
                        "Your blood glucose is at or below \(InsulinCalculator.hypoThresholdBG.display) mg/dL.\nStop the insulin calculation.\n\nTake 15–20g of fast-acting sugar now.\n(half a cup of juice, 3–4 candies, sugar water)\n\nRe-check your blood glucose in 15 minutes."))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                bgText = ""
                goBack(to: .bloodGlucose)
            } label: {
                Text(lang.t("혈당 다시 측정하기", "Re-check blood glucose"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)
        }
        .padding(24)
    }

    // MARK: 3) 식사량 입력

    private var mealPage: some View {
        StepPage(
            title: lang.t("무엇을 드시나요?", "What are you eating?"),
            subtitle: lang.t("음식 무게를 입력하면 탄수화물 양을 자동으로 계산합니다.",
                             "Enter the food weight and we'll estimate the carbs."),
            nextTitle: lang.t("다음", "Next"),
            isNextEnabled: carbsValue != nil,
            onNext: { advance(to: .result) }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Picker(lang.t("입력 방식", "Input mode"), selection: $inputMode) {
                    Text(lang.t("음식으로 입력", "By food")).tag(MealInputMode.food)
                    Text(lang.t("탄수화물 직접 입력", "Carbs directly")).tag(MealInputMode.carbs)
                }
                .pickerStyle(.segmented)

                if inputMode == .food {
                    HStack {
                        Text(lang.t("음식 종류", "Food"))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Picker(lang.t("음식 종류", "Food"), selection: $selectedFood) {
                            ForEach(FoodType.allCases) { food in
                                Text(food.name(lang)).tag(food)
                            }
                        }
                        .labelsHidden()
                    }
                    .padding(.horizontal, 4)

                    NumberInputField(placeholder: lang.t("섭취량", "Amount"),
                                     unit: "g", text: $weightText)

                    if let carbs = carbsValue {
                        Text(lang.t("계산된 탄수화물: 약 \(carbs.display1) g",
                                    "Estimated carbs: ≈ \(carbs.display1) g"))
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                } else {
                    NumberInputField(placeholder: lang.t("탄수화물", "Carbs"),
                                     unit: "g", text: $carbsText)
                }
            }
        }
    }

    // MARK: 4) 결과

    private var resultPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let bg = bgValue, let carbs = carbsValue,
                   let result = InsulinCalculator.calculate(
                       carbs: carbs,
                       currentBG: bg,
                       targetBG: targetBG,
                       icr: icr,
                       isf: isf,
                       penIncrement: penIncrement,
                       correctionEnabled: correctionEnabled
                   ) {
                    resultContent(result)
                } else {
                    invalidSettingsContent
                }
            }
            .padding(24)
        }
    }

    @ViewBuilder
    private func resultContent(_ result: BolusResult) -> some View {
        VStack(spacing: 8) {
            Text(lang.t("권장 인슐린", "Suggested insulin"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("\(result.totalRounded.display) U")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(.blue)
            Text(lang.t("계산값 \(result.totalRaw.display) U · 펜 단위(\(penIncrement.display) U) 내림 적용",
                        "Calculated \(result.totalRaw.display) U · rounded down to \(penIncrement.display) U pen increments"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16))

        VStack(spacing: 0) {
            detailRow(lang.t("섭취 탄수화물", "Carbs"), "\(result.carbs.display1) g")
            Divider()
            detailRow(lang.t("식사 인슐린 (탄수화물 ÷ ICR)", "Meal bolus (carbs ÷ ICR)"),
                      "\(result.mealBolus.display) U")
            Divider()
            if correctionEnabled {
                detailRow(lang.t("교정 인슐린 ((혈당−목표) ÷ ISF)", "Correction ((BG − target) ÷ ISF)"),
                          correctionText(result.correctionBolus))
            } else {
                detailRow(lang.t("교정 인슐린", "Correction"), lang.t("미적용", "Not applied"))
            }
        }
        .padding(.horizontal)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16))

        if !correctionEnabled, let bg = bgValue, bg >= 180 {
            NoticeBox(
                icon: "drop.fill",
                text: lang.t("현재 혈당(\(bg.display) mg/dL)이 높지만 ISF가 설정되지 않아 교정 인슐린은 계산에 포함되지 않았습니다. 교정 투여량은 담당 의료진과 상의하세요.",
                             "Your blood glucose (\(bg.display) mg/dL) is high, but no correction was calculated because ISF is not set. Consult your care team about correction dosing."),
                tint: .red
            )
        }

        NoticeBox(
            icon: "clock.badge.exclamationmark",
            text: lang.t("최근 3~4시간 안에 인슐린을 주사했다면 몸에 남아 있는 인슐린(잔여 인슐린, IOB)이 이 계산에 반영되지 않았습니다. 중복 투여 시 저혈당 위험이 있으니 주의하세요.",
                         "If you injected insulin within the last 3–4 hours, insulin still active in your body (insulin on board, IOB) is NOT included in this calculation. Stacking doses may cause hypoglycemia.")
        )
        NoticeBox(
            icon: "stethoscope",
            text: lang.t("본 결과는 입력한 설정값에 따른 참고용 계산입니다. 실제 투여량은 반드시 담당 의료진의 처방과 지침에 따르세요.",
                         "This result is a reference calculation based on your settings. Always follow your doctor's prescription and guidance for actual dosing."),
            tint: .blue
        )

        Button {
            restart()
        } label: {
            Text(lang.t("새로 계산하기", "Start over"))
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    @ViewBuilder
    private var invalidSettingsContent: some View {
        NoticeBox(
            icon: "exclamationmark.triangle.fill",
            text: lang.t("설정값(ICR/ISF)이 올바르지 않아 계산할 수 없습니다. 설정을 확인해 주세요.",
                         "Can't calculate because your settings (ICR/ISF) are invalid. Please check them."),
            tint: .red
        )
        Button {
            showSettings = true
        } label: {
            Text(lang.t("설정 열기", "Open Settings"))
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.headline)
        }
        .padding(.vertical, 12)
    }

    private func correctionText(_ value: Double) -> String {
        value < 0
            ? lang.t("−\(abs(value).display) U (감량)", "−\(abs(value).display) U (reduced)")
            : "+\(value.display) U"
    }

    // MARK: - 입력값 파싱

    private var bgValue: Double? {
        guard let v = bgText.parsedDouble, (20...600).contains(v) else { return nil }
        return v
    }

    private var carbsValue: Double? {
        switch inputMode {
        case .food:
            guard let weight = weightText.parsedDouble, weight > 0 else { return nil }
            return InsulinCalculator.carbs(foodWeight: weight, food: selectedFood)
        case .carbs:
            guard let carbs = carbsText.parsedDouble, carbs > 0 else { return nil }
            return carbs
        }
    }

    // MARK: - 페이지 이동

    private func advance(to next: Step) {
        hideKeyboard()
        isForward = true
        withAnimation(.easeInOut(duration: 0.3)) { step = next }
    }

    private func goBack(to previous: Step) {
        hideKeyboard()
        isForward = false
        withAnimation(.easeInOut(duration: 0.3)) { step = previous }
    }

    private func restart() {
        bgText = ""
        weightText = ""
        carbsText = ""
        advance(to: .bloodGlucose)
    }
}

// MARK: - 설정 화면

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SettingsKeys.icr) private var icr = 0.0
    @AppStorage(SettingsKeys.isf) private var isf = 0.0
    @AppStorage(SettingsKeys.targetBG) private var targetBG = 110.0
    @AppStorage(SettingsKeys.penIncrement) private var penIncrement = 1.0
    @AppStorage(SettingsKeys.correctionEnabled) private var correctionEnabled = true
    @AppStorage(SettingsKeys.isOnboarded) private var isOnboarded = false
    @AppStorage(SettingsKeys.language) private var languageRaw = AppLanguage.korean.rawValue

    private var lang: AppLanguage { AppLanguage(rawValue: languageRaw) ?? .korean }

    var body: some View {
        NavigationStack {
            Form {
                Section(lang.t("언어", "Language")) {
                    Picker(lang.t("언어", "Language"), selection: $languageRaw) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayName).tag(language.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    NavigationLink {
                        ICREditView()
                    } label: {
                        LabeledContent(lang.t("탄수화물 계수", "Carb ratio"),
                                       value: "\(icr.display1) g/U")
                    }
                } header: {
                    Text(lang.t("탄수화물 계수 (ICR)", "Carb ratio (ICR)"))
                } footer: {
                    Text(lang.t("탭하면 수정 페이지로 이동합니다. 밥 양·처방 기준·하루 총 인슐린으로 다시 계산할 수 있습니다.",
                                "Tap to open the edit page. You can recalculate from your usual meal, prescription, or total daily insulin."))
                }
                Section {
                    Toggle(lang.t("교정 인슐린 사용", "Use correction bolus"), isOn: $correctionEnabled)
                    if correctionEnabled {
                        HStack {
                            TextField(lang.t("민감도 지수", "Sensitivity factor"), value: $isf, format: .number)
                                .keyboardType(.decimalPad)
                            Text("mg/dL")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text(lang.t("인슐린 민감도 지수 (ISF)", "Insulin sensitivity factor (ISF)"))
                } footer: {
                    Text(correctionEnabled
                         ? lang.t("인슐린 1단위가 혈당을 몇 mg/dL 낮추는지 나타내는 값입니다.",
                                  "How much 1 unit of insulin lowers your blood glucose (mg/dL).")
                         : lang.t("ISF를 모르면 끈 상태로 두세요. 교정 인슐린 없이 식사 인슐린만 계산합니다.",
                                  "Leave off if you don't know your ISF. Only meal insulin will be calculated."))
                }
                Section(lang.t("목표 혈당", "Target blood glucose")) {
                    HStack {
                        TextField(lang.t("목표 혈당", "Target glucose"), value: $targetBG, format: .number)
                            .keyboardType(.decimalPad)
                        Text("mg/dL")
                            .foregroundStyle(.secondary)
                    }
                }
                Section(lang.t("인슐린 펜 단위", "Insulin pen increment")) {
                    Picker(lang.t("펜 단위", "Pen increment"), selection: $penIncrement) {
                        Text("1 U").tag(1.0)
                        Text("0.5 U").tag(0.5)
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    Button(lang.t("초기 설정 다시 하기", "Redo initial setup"), role: .destructive) {
                        isOnboarded = false
                        dismiss()
                    }
                } footer: {
                    Text(lang.t("본 앱의 계산 결과는 참고용입니다. 실제 인슐린 투여는 담당 의료진의 처방과 지침에 따르세요.",
                                "Results from this app are for reference only. Always follow your doctor's prescription and guidance for actual insulin dosing."))
                }
            }
            .navigationTitle(lang.t("설정", "Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(lang.t("완료", "Done")) { dismiss() }
                }
            }
        }
    }
}

#Preview {
    CalculatorView()
}
