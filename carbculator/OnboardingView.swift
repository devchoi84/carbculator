//
//  OnboardingView.swift
//  carbculator
//

import SwiftUI

/// 최초 실행 시 ICR / ISF / 목표 혈당 / 펜 단위를 설정하는 온보딩 마법사.
/// 한 페이지에 질문 하나씩, 값을 입력하면 부드러운 전환으로 다음 페이지로 넘어간다.
struct OnboardingView: View {
    private enum Step: Int, CaseIterable {
        case icrMethod
        case icrInput
        case isfMethod
        case isfInput
        case targetBG
        case penUnit
        case summary
    }

    private enum ICRMethod {
        case meal          // 평소 식사(밥 양 + 인슐린 양) 기반 역산
        case direct        // 계수를 이미 알고 있음
        case prescription  // 병원 처방 기준 역산
        case tdd           // 하루 총 인슐린 기반 추정 (500의 법칙)
    }

    private enum ISFMethod {
        case direct    // 값을 이미 알고 있음
        case tdd       // 하루 총 인슐린 기반 추정 (1800의 법칙)
        case estimate  // ICR 기반 추정 (ISF ≈ ICR × 3.6, 500·1800 법칙의 비율)
        case skip      // 교정 인슐린 없이 식사 인슐린만 계산
    }

    @AppStorage(SettingsKeys.icr) private var storedICR = 0.0
    @AppStorage(SettingsKeys.isf) private var storedISF = 0.0
    @AppStorage(SettingsKeys.targetBG) private var storedTargetBG = 110.0
    @AppStorage(SettingsKeys.penIncrement) private var storedPenIncrement = 1.0
    @AppStorage(SettingsKeys.correctionEnabled) private var storedCorrectionEnabled = true
    @AppStorage(SettingsKeys.isOnboarded) private var isOnboarded = false
    @AppStorage(SettingsKeys.language) private var languageRaw = AppLanguage.korean.rawValue

    @State private var step: Step = .icrMethod
    @State private var isForward = true
    @State private var method: ICRMethod = .meal
    @State private var isfMethod: ISFMethod = .direct

    // 입력값 (문자열로 받아 파싱)
    @State private var icrText = ""
    @State private var carbsText = ""
    @State private var unitsText = ""
    @State private var tddText = ""
    @State private var mealFood: FoodType = .whiteRice
    @State private var mealWeightText = ""
    @State private var mealUnitsText = ""
    @State private var isfText = ""
    @State private var targetText = "110"
    @State private var penIncrement = 1.0

    private var lang: AppLanguage { AppLanguage(rawValue: languageRaw) ?? .korean }

    var body: some View {
        VStack(spacing: 0) {
            header
            ZStack {
                stepContent
                    .id(step)
                    .transition(.stepPush(forward: isForward))
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(lang.t("완료", "Done")) { hideKeyboard() }
            }
        }
    }

    // MARK: - 헤더 (언어 전환/뒤로 가기 + 진행도)

    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                if step == .icrMethod {
                    // 첫 페이지에서만 한/영 전환 버튼 노출
                    Button {
                        languageRaw = (lang == .korean ? AppLanguage.english : AppLanguage.korean).rawValue
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "globe")
                            Text(lang == .korean ? "English" : "한국어")
                        }
                        .font(.subheadline)
                    }
                } else {
                    Button {
                        goBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                    }
                }
                Spacer()
                Text("\(step.rawValue + 1) / \(Step.allCases.count)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(height: 24)

            ProgressView(value: Double(step.rawValue + 1), total: Double(Step.allCases.count))
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    // MARK: - 단계별 페이지

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .icrMethod: icrMethodPage
        case .icrInput: icrInputPage
        case .isfMethod: isfMethodPage
        case .isfInput: isfInputPage
        case .targetBG: targetPage
        case .penUnit: penUnitPage
        case .summary: summaryPage
        }
    }

    private var icrMethodPage: some View {
        StepPage(
            title: lang.t("탄수화물 계수(ICR)를\n어떻게 설정할까요?",
                          "How would you like to set\nyour carb ratio (ICR)?"),
            subtitle: lang.t("탄수화물 계수는 인슐린 1단위(U)가 처리할 수 있는 탄수화물 양(g)입니다.",
                             "Your carb ratio is the grams of carbohydrate covered by 1 unit (U) of insulin.")
        ) {
            VStack(spacing: 12) {
                OptionRowButton(
                    title: lang.t("식사하는 밥 양으로 계산할게요", "Calculate from my usual meal"),
                    subtitle: lang.t("평소 먹는 밥 양과 그때 주사하는 인슐린 양으로 계산 (추천)",
                                     "Based on the rice you usually eat and the insulin you inject (Recommended)")
                ) {
                    method = .meal
                    advance(to: .icrInput)
                }
                OptionRowButton(
                    title: lang.t("계수를 알고 있어요", "I know my ratio"),
                    subtitle: lang.t("예: 탄수화물 10g당 1단위", "e.g. 1 unit per 10g of carbs")
                ) {
                    method = .direct
                    advance(to: .icrInput)
                }
                OptionRowButton(
                    title: lang.t("병원 처방 기준으로 계산할게요", "Calculate from my doctor's guidance"),
                    subtitle: lang.t("예: “탄수화물 60g 먹을 때 6단위 주사” 기준을 그대로 입력",
                                     "e.g. enter “6 units for 60g of carbs” as prescribed")
                ) {
                    method = .prescription
                    advance(to: .icrInput)
                }
                OptionRowButton(
                    title: lang.t("하루 총 인슐린 양으로 추정할게요", "Estimate from my total daily insulin"),
                    subtitle: lang.t("기초 + 식사 인슐린 하루 총량으로 추정 (500의 법칙)",
                                     "Based on basal + bolus daily total (500 rule)")
                ) {
                    method = .tdd
                    advance(to: .icrInput)
                }

                SourceLink(label: lang.t("출처: UCSF 당뇨 교육센터 (탄수화물 계수·500의 법칙)",
                                         "Source: UCSF Diabetes Teaching Center (carb ratio · 500 rule)"),
                           url: MedicalSources.insulinDoseCalc)
                    .padding(.top, 4)
            }
        }
    }

    @ViewBuilder
    private var icrInputPage: some View {
        switch method {
        case .meal:
            StepPage(
                title: lang.t("평소 식사 기준을 입력하세요", "Enter your usual meal"),
                subtitle: lang.t("평소 먹는 밥 양과 그 식사에 주사하는 인슐린 양으로 계수를 자동 계산합니다.",
                                 "We'll calculate your ratio from the food you usually eat and the insulin you inject for it."),
                nextTitle: lang.t("다음", "Next"),
                isNextEnabled: icrValue != nil,
                onNext: { advance(to: .isfMethod) }
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(lang.t("주식 종류", "Staple food"))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Picker(lang.t("주식 종류", "Staple food"), selection: $mealFood) {
                            ForEach(FoodType.allCases) { food in
                                Text(food.name(lang)).tag(food)
                            }
                        }
                        .labelsHidden()
                    }
                    .padding(.horizontal, 4)

                    NumberInputField(placeholder: lang.t("평소 먹는 밥 양", "Usual food amount"),
                                     unit: "g", text: $mealWeightText)
                    NumberInputField(placeholder: lang.t("그때 주사하는 인슐린", "Insulin for that meal"),
                                     unit: "U", text: $mealUnitsText)

                    if let weight = mealWeightText.parsedDouble, weight > 0 {
                        Text(lang.t("탄수화물 약 \(InsulinCalculator.carbs(foodWeight: weight, food: mealFood).display1) g",
                                    "≈ \(InsulinCalculator.carbs(foodWeight: weight, food: mealFood).display1) g of carbs"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let icr = icrValue {
                        Text(lang.t("계산된 탄수화물 계수: \(icr.display1) g/U",
                                    "Calculated carb ratio: \(icr.display1) g/U"))
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }

                    NoticeBox(
                        icon: "exclamationmark.triangle",
                        text: lang.t("평소 용량이 잘 맞고 있다는 전제의 추정치입니다. 식후 혈당이 계속 높거나 낮았다면 담당 의료진과 계수를 조정하세요.",
                                     "This assumes your usual dose has been working well. If your post-meal glucose runs high or low, adjust the ratio with your care team.")
                    )
                }
            }
        case .direct:
            StepPage(
                title: lang.t("탄수화물 계수를 입력하세요", "Enter your carb ratio"),
                subtitle: lang.t("인슐린 1단위가 처리하는 탄수화물 양(g)입니다.",
                                 "Grams of carbohydrate covered by 1 unit of insulin."),
                nextTitle: lang.t("다음", "Next"),
                isNextEnabled: icrValue != nil,
                onNext: { advance(to: .isfMethod) }
            ) {
                NumberInputField(placeholder: lang.t("탄수화물 계수", "Carb ratio"),
                                 unit: "g/U", text: $icrText)
            }
        case .prescription:
            StepPage(
                title: lang.t("처방 기준을 입력하세요", "Enter your prescribed basis"),
                subtitle: lang.t("의료진이 안내해 준 식사 인슐린 기준을 그대로 입력하면 계수를 자동 계산합니다.",
                                 "Enter your doctor's meal insulin guidance as-is and we'll calculate the ratio."),
                nextTitle: lang.t("다음", "Next"),
                isNextEnabled: icrValue != nil,
                onNext: { advance(to: .isfMethod) }
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    NumberInputField(placeholder: lang.t("먹는 탄수화물", "Carbs eaten"),
                                     unit: "g", text: $carbsText)
                    NumberInputField(placeholder: lang.t("주사하는 인슐린", "Insulin injected"),
                                     unit: "U", text: $unitsText)
                    if let icr = icrValue {
                        Text(lang.t("계산된 탄수화물 계수: \(icr.display1) g/U",
                                    "Calculated carb ratio: \(icr.display1) g/U"))
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                }
            }
        case .tdd:
            StepPage(
                title: lang.t("하루 총 인슐린 양을 입력하세요", "Enter your total daily insulin"),
                subtitle: lang.t("기초 인슐린(트레시바 등)과 모든 식사 인슐린을 더한 하루 평균 총량(TDD)입니다.",
                                 "Your average daily total (TDD) of basal insulin (e.g. Tresiba) plus all meal insulin."),
                nextTitle: lang.t("다음", "Next"),
                isNextEnabled: icrValue != nil,
                onNext: { advance(to: .isfMethod) }
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    NumberInputField(placeholder: lang.t("하루 총 인슐린", "Total daily insulin"),
                                     unit: "U", text: $tddText)
                    if let icr = icrValue {
                        Text(lang.t("추정 탄수화물 계수: \(icr.display1) g/U",
                                    "Estimated carb ratio: \(icr.display1) g/U"))
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                    NoticeBox(
                        icon: "exclamationmark.triangle",
                        text: lang.t("500의 법칙에 따른 의학적 추정치입니다. 실제 적용 전 담당 의료진과 상의하세요.",
                                     "A medical estimate based on the 500 rule. Consult your care team before applying.")
                    )
                }
            }
        }
    }

    private var isfMethodPage: some View {
        StepPage(
            title: lang.t("인슐린 민감도 지수(ISF)를\n알고 계신가요?",
                          "Do you know your insulin\nsensitivity factor (ISF)?"),
            subtitle: lang.t("인슐린 1단위가 혈당을 몇 mg/dL 낮추는지 나타내는 값으로, 높은 혈당을 교정하는 인슐린 계산에 사용됩니다.",
                             "ISF is how much 1 unit of insulin lowers your blood glucose (mg/dL). It's used to calculate correction doses for high readings.")
        ) {
            VStack(spacing: 12) {
                OptionRowButton(
                    title: lang.t("알고 있어요", "I know it"),
                    subtitle: lang.t("값을 직접 입력합니다", "Enter the value directly")
                ) {
                    isfMethod = .direct
                    advance(to: .isfInput)
                }
                OptionRowButton(
                    title: lang.t("하루 총 인슐린 양으로 추정할게요", "Estimate from my total daily insulin"),
                    subtitle: lang.t("기초 + 식사 인슐린 하루 총량으로 추정 (1800의 법칙)",
                                     "Based on basal + bolus daily total (1800 rule)")
                ) {
                    isfMethod = .tdd
                    advance(to: .isfInput)
                }
                OptionRowButton(
                    title: lang.t("잘 모르겠어요 — 추정값으로 시작할게요", "Not sure — start with an estimate"),
                    subtitle: lang.t("앞서 계산한 탄수화물 계수로 추정합니다 (ISF ≈ ICR × 3.6)",
                                     "Estimated from your carb ratio (ISF ≈ ICR × 3.6)")
                ) {
                    isfMethod = .estimate
                    if let icr = icrValue {
                        isfText = (icr * 3.6).rounded().display
                    }
                    advance(to: .isfInput)
                }
                OptionRowButton(
                    title: lang.t("교정 인슐린 없이 계산할게요", "Skip correction bolus"),
                    subtitle: lang.t("높은 혈당 교정 없이 식사 인슐린만 계산합니다",
                                     "Calculate meal insulin only, without corrections")
                ) {
                    isfMethod = .skip
                    advance(to: .penUnit)
                }

                SourceLink(label: lang.t("출처: UCSF 당뇨 교육센터 (민감도 지수·1800의 법칙)",
                                         "Source: UCSF Diabetes Teaching Center (ISF · 1800 rule)"),
                           url: MedicalSources.insulinDoseCalc)
                    .padding(.top, 4)
            }
        }
    }

    @ViewBuilder
    private var isfInputPage: some View {
        switch isfMethod {
        case .direct, .skip:
            StepPage(
                title: lang.t("인슐린 민감도 지수를\n입력하세요", "Enter your insulin\nsensitivity factor"),
                subtitle: lang.t("인슐린 1단위가 혈당을 몇 mg/dL 낮추는지 나타내는 값입니다.",
                                 "How much 1 unit of insulin lowers your blood glucose (mg/dL)."),
                nextTitle: lang.t("다음", "Next"),
                isNextEnabled: isfValue != nil,
                onNext: { advance(to: .targetBG) }
            ) {
                NumberInputField(placeholder: lang.t("민감도 지수", "Sensitivity factor"),
                                 unit: "mg/dL", text: $isfText)
            }
        case .estimate:
            StepPage(
                title: lang.t("추정된 민감도 지수를\n확인하세요", "Review your estimated\nsensitivity factor"),
                subtitle: lang.t("탄수화물 계수(\(icrValue?.display1 ?? "-") g/U)를 바탕으로 추정한 값입니다. 필요하면 수정하세요.",
                                 "Estimated from your carb ratio (\(icrValue?.display1 ?? "-") g/U). Adjust if needed."),
                nextTitle: lang.t("다음", "Next"),
                isNextEnabled: isfValue != nil,
                onNext: { advance(to: .targetBG) }
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    NumberInputField(placeholder: lang.t("민감도 지수", "Sensitivity factor"),
                                     unit: "mg/dL", text: $isfText)
                    NoticeBox(
                        icon: "exclamationmark.triangle",
                        text: lang.t("500·1800 법칙의 비율(ICR × 3.6)에 따른 추정치로, 실제 민감도와 다를 수 있습니다. 처음에는 식후 혈당이 낮아지지 않는지 잘 지켜보고, 담당 의료진과 함께 조정하세요.",
                                     "An estimate based on the 500/1800 rule ratio (ICR × 3.6); your actual sensitivity may differ. Watch for low readings at first and adjust with your care team.")
                    )
                }
            }
        case .tdd:
            StepPage(
                title: lang.t("하루 총 인슐린 양을 입력하세요", "Enter your total daily insulin"),
                subtitle: lang.t("기초 인슐린(트레시바 등)과 모든 식사 인슐린을 더한 하루 평균 총량(TDD)입니다.",
                                 "Your average daily total (TDD) of basal insulin (e.g. Tresiba) plus all meal insulin."),
                nextTitle: lang.t("다음", "Next"),
                isNextEnabled: isfValue != nil,
                onNext: { advance(to: .targetBG) }
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    NumberInputField(placeholder: lang.t("하루 총 인슐린", "Total daily insulin"),
                                     unit: "U", text: $tddText)
                    if let isf = isfValue {
                        Text(lang.t("추정 민감도 지수: \(isf.display1) mg/dL",
                                    "Estimated sensitivity factor: \(isf.display1) mg/dL"))
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                    NoticeBox(
                        icon: "exclamationmark.triangle",
                        text: lang.t("1800의 법칙에 따른 의학적 추정치입니다. 실제 적용 전 담당 의료진과 상의하세요.",
                                     "A medical estimate based on the 1800 rule. Consult your care team before applying.")
                    )
                }
            }
        }
    }

    private var targetPage: some View {
        StepPage(
            title: lang.t("목표 혈당을 입력하세요", "Enter your target blood glucose"),
            subtitle: lang.t("식전에 유지하고 싶은 목표 혈당입니다. 보통 100~120 mg/dL로 설정합니다.",
                             "The pre-meal blood glucose you aim for. Typically 100–120 mg/dL."),
            nextTitle: lang.t("다음", "Next"),
            isNextEnabled: targetValue != nil,
            onNext: { advance(to: .penUnit) }
        ) {
            VStack(alignment: .leading, spacing: 12) {
                NumberInputField(placeholder: lang.t("목표 혈당", "Target glucose"),
                                 unit: "mg/dL", text: $targetText)
                if let v = targetText.parsedDouble, !(80...180).contains(v) {
                    Text(lang.t("80~180 mg/dL 사이의 값을 입력해 주세요.",
                                "Please enter a value between 80 and 180 mg/dL."))
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var penUnitPage: some View {
        StepPage(
            title: lang.t("인슐린 펜의 최소 단위는?", "What's your pen's smallest increment?"),
            subtitle: lang.t("저혈당 방지를 위해 계산 결과를 펜 단위로 내림 처리합니다.",
                             "Results are rounded down to pen increments to help prevent hypoglycemia.")
        ) {
            VStack(spacing: 12) {
                OptionRowButton(
                    title: lang.t("1 U 단위 펜", "1 U pen"),
                    subtitle: lang.t("대부분의 성인용 인슐린 펜", "Most adult insulin pens")
                ) {
                    penIncrement = 1.0
                    advance(to: .summary)
                }
                OptionRowButton(
                    title: lang.t("0.5 U 단위 펜", "0.5 U pen"),
                    subtitle: lang.t("소아용 / 하프 단위 펜", "Pediatric / half-unit pens")
                ) {
                    penIncrement = 0.5
                    advance(to: .summary)
                }
            }
        }
    }

    private var summaryPage: some View {
        StepPage(
            title: lang.t("설정을 확인해 주세요", "Review your settings"),
            subtitle: lang.t("설정값은 언제든 메인 화면의 설정 메뉴에서 수정할 수 있습니다.",
                             "You can change these anytime in Settings on the main screen."),
            nextTitle: lang.t("설정 완료", "Finish"),
            isNextEnabled: icrValue != nil && (isfMethod == .skip || (isfValue != nil && targetValue != nil)),
            onNext: { complete() }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(spacing: 0) {
                    summaryRow(lang.t("탄수화물 계수 (ICR)", "Carb ratio (ICR)"),
                               "\(icrValue?.display1 ?? "-") g/U")
                    Divider()
                    summaryRow(
                        lang.t("인슐린 민감도 (ISF)", "Sensitivity (ISF)"),
                        isfMethod == .skip
                            ? lang.t("미설정 (교정 안 함)", "Not set (no correction)")
                            : "\(isfValue?.display1 ?? "-") mg/dL"
                    )
                    Divider()
                    if isfMethod != .skip {
                        summaryRow(lang.t("목표 혈당", "Target glucose"),
                                   "\(targetValue?.display1 ?? "-") mg/dL")
                        Divider()
                    }
                    summaryRow(lang.t("펜 단위", "Pen increment"), "\(penIncrement.display) U")
                }
                .padding(.horizontal)
                .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16))

                if isfMethod == .skip {
                    NoticeBox(
                        icon: "info.circle",
                        text: lang.t("교정 인슐린 없이 식사 인슐린만 계산합니다. ISF를 알게 되면 설정 메뉴에서 입력하고 교정 기능을 켤 수 있습니다.",
                                     "Only meal insulin will be calculated, without corrections. Once you know your ISF, enter it in Settings and turn corrections on."),
                        tint: .blue
                    )
                }

                NoticeBox(
                    icon: "stethoscope",
                    text: lang.t("이 값들은 참고용 시작점입니다. 식후 혈당 반응을 보며 담당 의료진과 함께 조정하세요.",
                                 "These values are a reference starting point. Adjust them with your care team based on your post-meal glucose.")
                )
            }
        }
    }

    private func summaryRow(_ label: String, _ value: String) -> some View {
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

    // MARK: - 입력값 파싱

    private var icrValue: Double? {
        switch method {
        case .meal:
            guard let weight = mealWeightText.parsedDouble, let units = mealUnitsText.parsedDouble,
                  weight > 0, units > 0 else { return nil }
            return InsulinCalculator.carbs(foodWeight: weight, food: mealFood) / units
        case .direct:
            guard let v = icrText.parsedDouble, v > 0 else { return nil }
            return v
        case .prescription:
            guard let carbs = carbsText.parsedDouble, let units = unitsText.parsedDouble,
                  carbs > 0, units > 0 else { return nil }
            return carbs / units
        case .tdd:
            guard let tdd = tddText.parsedDouble, tdd > 0 else { return nil }
            return 500 / tdd
        }
    }

    private var isfValue: Double? {
        switch isfMethod {
        case .direct, .estimate:
            guard let v = isfText.parsedDouble, v > 0 else { return nil }
            return v
        case .tdd:
            guard let tdd = tddText.parsedDouble, tdd > 0 else { return nil }
            return (1800 / tdd).rounded()
        case .skip:
            return nil
        }
    }

    private var targetValue: Double? {
        guard let v = targetText.parsedDouble, (80...180).contains(v) else { return nil }
        return v
    }

    // MARK: - 페이지 이동

    private func advance(to next: Step) {
        hideKeyboard()
        isForward = true
        withAnimation(.easeInOut(duration: 0.3)) { step = next }
    }

    private func goBack() {
        let previous: Step
        if step == .penUnit && isfMethod == .skip {
            // ISF를 건너뛴 경우 입력/목표 혈당 단계를 거치지 않고 방식 선택으로 돌아간다
            previous = .isfMethod
        } else if let p = Step(rawValue: step.rawValue - 1) {
            previous = p
        } else {
            return
        }
        hideKeyboard()
        isForward = false
        withAnimation(.easeInOut(duration: 0.3)) { step = previous }
    }

    // MARK: - 저장

    private func complete() {
        guard let icr = icrValue else { return }
        if isfMethod == .skip {
            storedISF = 0
            storedCorrectionEnabled = false
        } else {
            guard let isf = isfValue, let target = targetValue else { return }
            storedISF = isf
            storedTargetBG = target
            storedCorrectionEnabled = true
        }
        storedICR = icr
        storedPenIncrement = penIncrement
        withAnimation(.easeInOut(duration: 0.3)) { isOnboarded = true }
    }
}

#Preview {
    OnboardingView()
}
