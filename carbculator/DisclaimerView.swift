//
//  DisclaimerView.swift
//  carbculator
//
//  앱 실행 시 표시하는 참고용 안내 팝업.
//  '확인'은 이번 실행에서만 닫고, '다시 보지 않기'는 이후 표시하지 않는다.
//

import SwiftUI

struct DisclaimerView: View {
    @AppStorage(SettingsKeys.language) private var languageRaw = AppLanguage.korean.rawValue

    /// 이번만 닫기
    let onConfirm: () -> Void
    /// 다시 보지 않기
    let onDontShowAgain: () -> Void

    private var lang: AppLanguage { AppLanguage(rawValue: languageRaw) ?? .korean }

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "stethoscope")
                    .font(.system(size: 44))
                    .foregroundStyle(.blue)

                Text(lang.t("참고용 안내", "Please note"))
                    .font(.title2.bold())

                Text(lang.t("이 앱의 계산 결과는 참고용입니다. 가장 정확한 인슐린 용량은 담당 의료진의 처방과 지침에 따르는 것입니다. 실제 투여 전 반드시 의료진과 상의하세요.",
                            "Results in this app are for reference only. The most accurate insulin dose comes from your doctor's prescription and guidance. Always consult your care team before dosing."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 10) {
                    Button(action: onConfirm) {
                        Text(lang.t("확인", "OK"))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button(action: onDontShowAgain) {
                        Text(lang.t("다시 보지 않기", "Don't show again"))
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(24)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 20))
            .padding(32)
        }
    }
}

#Preview {
    DisclaimerView(onConfirm: {}, onDontShowAgain: {})
}
