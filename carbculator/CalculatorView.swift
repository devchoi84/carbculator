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
    @State private var carbsText = ""

    // 음식 검색 상태
    @State private var foodQuery = ""
    @State private var searchResults: [FoodItem] = []
    @State private var isSearching = false
    @State private var searchFailed = false
    @State private var selectedFoods: [SelectedFood] = []

    /// 한 끼에 선택한 음식 한 건. 같은 음식을 여러 번 담을 수 있도록 고유 id를 부여한다.
    private struct SelectedFood: Identifiable, Equatable {
        let id = UUID()
        let item: FoodItem
    }

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
                guard bgValue != nil else { return }
                // 저혈당이어도 막지 않고 진행한다. 낮은 혈당은 교정 인슐린으로
                // 권장량에 자동 반영되며, 결과 화면에서 저혈당 주의를 안내한다.
                advance(to: .meal)
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

    // MARK: 2) 식사량 입력

    private var mealPage: some View {
        StepPage(
            title: lang.t("무엇을 드시나요?", "What are you eating?"),
            subtitle: lang.t("음식을 검색해 선택하면 100g당 탄수화물이 자동으로 입력됩니다.",
                             "Search and pick a food to auto-fill its carbs per 100g."),
            nextTitle: lang.t("다음", "Next"),
            isNextEnabled: carbsValue != nil,
            onNext: { advance(to: .result) }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Picker(lang.t("입력 방식", "Input mode"), selection: $inputMode) {
                    Text(lang.t("음식 검색", "Search food")).tag(MealInputMode.food)
                    Text(lang.t("탄수화물 직접 입력", "Carbs directly")).tag(MealInputMode.carbs)
                }
                .pickerStyle(.segmented)

                if inputMode == .food {
                    foodSearchField

                    Label(lang.t("식품의약품안전처(식약처) 식품영양성분 데이터베이스 기반",
                                 "Powered by the Korea MFDS food nutrition database"),
                          systemImage: "checkmark.seal.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if isSearching {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text(lang.t("검색 중…", "Searching…"))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } else if searchFailed {
                        Text(lang.t("검색에 실패했습니다. 잠시 후 다시 시도하거나 탄수화물을 직접 입력하세요.",
                                    "Search failed. Try again later or enter carbs directly."))
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    if !searchResults.isEmpty {
                        searchResultList
                    }

                    if !selectedFoods.isEmpty {
                        selectedFoodsList
                    }

                    NumberInputField(placeholder: lang.t("탄수화물 (합계)", "Carbs (total)"),
                                     unit: "g", text: $carbsText)
                    Text(lang.t("각 음식은 100g 기준으로 합산됩니다. 실제 드시는 양에 맞게 조정하세요.",
                                "Each food is summed on a per-100 g basis. Adjust to the amount you actually eat."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    NumberInputField(placeholder: lang.t("탄수화물", "Carbs"),
                                     unit: "g", text: $carbsText)
                }
            }
            .task(id: foodQuery) { await performFoodSearch() }
        }
    }

    // 음식 검색 입력 필드
    private var foodSearchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(lang.t("음식 검색 (예: 쌀밥, 닭가슴살)", "Search food (e.g. rice)"),
                      text: $foodQuery)
            if !foodQuery.isEmpty {
                Button {
                    foodQuery = ""
                    searchResults = []
                    searchFailed = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 12))
    }

    // 검색 결과 리스트 (상위 8건)
    private var searchResultList: some View {
        let shown = Array(searchResults.prefix(8))
        return VStack(spacing: 0) {
            ForEach(shown) { item in
                Button {
                    selectFood(item)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            Text(lang.t("탄수화물 \(item.carbsPer100g.display1) g / 100g",
                                        "Carbs \(item.carbsPer100g.display1) g / 100g"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "plus.circle")
                            .foregroundStyle(.blue)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if item.id != shown.last?.id {
                    Divider()
                }
            }
        }
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 12))
    }

    // 선택한 음식 목록 (탄수화물 합계에 반영됨)
    private var selectedFoodsList: some View {
        VStack(spacing: 0) {
            ForEach(selectedFoods) { sel in
                HStack {
                    Text(sel.item.name)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(sel.item.carbsPer100g.display1) g")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button {
                        removeFood(sel)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                if sel.id != selectedFoods.last?.id {
                    Divider()
                }
            }
        }
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 12))
    }

    private func selectFood(_ item: FoodItem) {
        selectedFoods.append(SelectedFood(item: item))
        syncCarbsFromFoods()
        // 다음 음식을 바로 검색할 수 있도록 검색어·결과를 비운다. (키보드는 유지)
        foodQuery = ""
        searchResults = []
    }

    private func removeFood(_ sel: SelectedFood) {
        selectedFoods.removeAll { $0.id == sel.id }
        syncCarbsFromFoods()
    }

    /// 선택 음식들의 탄수화물 합계를 탄수화물 입력창에 반영한다.
    private func syncCarbsFromFoods() {
        let total = selectedFoods.reduce(0) { $0 + $1.item.carbsPer100g }
        carbsText = selectedFoods.isEmpty ? "" : total.display1
    }

    /// 검색어 변경 시 디바운스 후 API를 호출한다. (`.task(id:)`가 이전 호출을 취소)
    private func performFoodSearch() async {
        let q = foodQuery.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else {
            searchResults = []
            searchFailed = false
            isSearching = false
            return
        }
        // 디바운스: 입력이 이어지면 이 태스크가 취소되어 여기서 빠져나간다.
        do { try await Task.sleep(nanoseconds: 300_000_000) }
        catch { return }

        isSearching = true
        searchFailed = false
        do {
            let items = try await FoodSearchService.search(q)
            if Task.isCancelled { return }
            searchResults = items
        } catch {
            if Task.isCancelled { return }   // 다음 검색으로 대체된 경우
            searchResults = []
            searchFailed = true
        }
        isSearching = false
    }

    // MARK: 3) 결과

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
        if let bg = bgValue, bg <= InsulinCalculator.hypoThresholdBG {
            hypoNotice(bg: bg)
        }

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

    /// 저혈당 범위(혈당 ≤ 임계값)에서 결과 화면 상단에 표시하는 주의 안내.
    /// 교정(ISF) 사용 여부에 따라 안내 문구가 달라진다.
    private func hypoNotice(bg: Double) -> some View {
        let text: String
        if correctionEnabled {
            // 교정 인슐린이 켜져 있으면 낮은 혈당이 권장량에 자동 반영(감량)된다.
            text = lang.t(
                "현재 혈당(\(bg.display) mg/dL)이 저혈당 범위입니다. 아래 권장량은 낮은 혈당을 반영해 자동으로 줄여 계산되었습니다.\n\n일반적으로는 단순당 15~20g으로 저혈당을 먼저 처치한 뒤 식사하는 것이 안전합니다. 저혈당 처치 후 식사를 시작하면서 투여하고, 반드시 담당 의료진의 지침을 따르세요.",
                "Your blood glucose (\(bg.display) mg/dL) is in the hypoglycemia range. The dose below has been automatically reduced to account for your low reading.\n\nIt's generally safer to treat the low with 15–20 g of fast-acting sugar first, then eat. Inject as you start eating after treating the low, and always follow your care team's guidance."
            )
        } else {
            // 교정이 꺼져 있으면 자동 감량이 되지 않으므로 더 강하게 경고한다.
            text = lang.t(
                "현재 혈당(\(bg.display) mg/dL)이 저혈당 범위입니다. 교정 인슐린이 꺼져 있어 권장량이 낮은 혈당에 맞게 자동으로 줄어들지 않았습니다.\n\n단순당 15~20g으로 저혈당을 먼저 처치하고, 투여량을 줄이거나 미루는 것을 담당 의료진과 상의하세요.",
                "Your blood glucose (\(bg.display) mg/dL) is in the hypoglycemia range. Correction is turned off, so the dose was NOT automatically reduced for your low reading.\n\nTreat the low with 15–20 g of fast-acting sugar first, and consult your care team about lowering or delaying the dose."
            )
        }
        return NoticeBox(icon: "exclamationmark.triangle.fill", text: text, tint: .red)
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
        // 두 모드 모두 최종적으로 탄수화물 입력값(carbsText)을 사용한다.
        // 음식 검색 모드에서는 선택 시 100g당 값이 자동 입력되며, 사용자가 조정할 수 있다.
        guard let carbs = carbsText.parsedDouble, carbs > 0 else { return nil }
        return carbs
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
        carbsText = ""
        foodQuery = ""
        searchResults = []
        searchFailed = false
        selectedFoods = []
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
