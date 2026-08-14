//
//  ReferencesView.swift
//  carbculator
//
//  앱의 계산·의학 정보에 대한 출처(citation). App Store 가이드라인 1.4.1 대응.
//  설정과 결과 화면에서 접근 가능하며, 각 항목은 원 출처로 연결된다.
//

import SwiftUI

// MARK: - 출처 URL 상수 (페이지 내 ⓘ 링크와 출처 화면이 공유)

enum MedicalSources {
    /// UCSF Diabetes Teaching Center — 인슐린 용량 공식, 500/1800 법칙
    static let insulinDoseCalc = URL(string: "https://diabetesteachingcenter.ucsf.edu/about-diabetes/type-2-diabetes/use-insulin-type-2-diabetes/calculating-insulin-dose")!
    /// ADA — 저혈당 대응
    static let hypoglycemia = URL(string: "https://diabetes.org/living-with-diabetes/hypoglycemia-low-blood-glucose")!
}

// MARK: - 페이지 내 출처 링크 (ⓘ + 라벨)

/// 개별 페이지에서 관련 출처로 바로 연결하는 작은 인라인 링크.
struct SourceLink: View {
    let label: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            Label(label, systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.blue)
        }
    }
}

struct ReferenceItem: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let url: URL
}

struct ReferencesView: View {
    @AppStorage(SettingsKeys.language) private var languageRaw = AppLanguage.korean.rawValue
    private var lang: AppLanguage { AppLanguage(rawValue: languageRaw) ?? .korean }

    private var items: [ReferenceItem] {
        [
            ReferenceItem(
                title: lang.t("인슐린 용량 계산 공식 · 500/1800 법칙",
                              "Insulin dose formulas · 500/1800 rules"),
                detail: lang.t("식사 인슐린(탄수화물÷ICR), 교정 인슐린((혈당−목표)÷ISF), 그리고 ICR=500÷TDD·ISF=1800÷TDD 추정의 근거.",
                               "Meal bolus (carbs÷ICR), correction ((BG−target)÷ISF), and the ICR=500÷TDD / ISF=1800÷TDD estimates."),
                url: URL(string: "https://diabetesteachingcenter.ucsf.edu/about-diabetes/type-2-diabetes/use-insulin-type-2-diabetes/calculating-insulin-dose")!
            ),
            ReferenceItem(
                title: lang.t("저혈당 대응 (혈당 70 mg/dL 미만)",
                              "Hypoglycemia (below 70 mg/dL)"),
                detail: lang.t("혈당 70 mg/dL 미만 시 단순당 15g 섭취 후 재확인(15-15 규칙) 등 저혈당 대응 근거.",
                               "Treating below 70 mg/dL with 15 g of fast-acting carbs and rechecking (15-15 rule)."),
                url: URL(string: "https://diabetes.org/living-with-diabetes/hypoglycemia-low-blood-glucose")!
            ),
            ReferenceItem(
                title: lang.t("목표 혈당 · 당뇨 관리 일반",
                              "Target glucose · general diabetes care"),
                detail: lang.t("목표 혈당 범위 등 일반적인 당뇨 관리 기준 (미국당뇨협회, ADA).",
                               "Target glucose ranges and general diabetes management (American Diabetes Association)."),
                url: URL(string: "https://diabetes.org")!
            ),
            ReferenceItem(
                title: lang.t("음식 영양(탄수화물) 데이터",
                              "Food carbohydrate data"),
                detail: lang.t("음식 검색의 탄수화물 값은 식품의약품안전처 식품영양성분 데이터베이스(공공데이터포털)를 기반으로 합니다.",
                               "Carb values come from the Korea MFDS food nutrition database (public data portal)."),
                url: URL(string: "https://www.data.go.kr")!
            ),
        ]
    }

    var body: some View {
        List {
            Section {
                ForEach(items) { item in
                    Link(destination: item.url) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.title)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .foregroundStyle(.blue)
                            }
                            Text(item.detail)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Text(lang.t("계산 및 의학 정보 출처", "Sources for calculations & medical info"))
            } footer: {
                Text(lang.t("이 앱의 계산과 안내는 위 출처를 참고한 것으로 참고용이며, 의료기기가 아닙니다. 실제 인슐린 투여는 반드시 담당 의료진의 처방과 지침을 따르세요.",
                            "The app's calculations and guidance reference the sources above and are for reference only; this is not a medical device. Always follow your doctor's prescription and guidance for actual insulin dosing."))
            }
        }
        .navigationTitle(lang.t("정보 출처", "References"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { ReferencesView() }
}
