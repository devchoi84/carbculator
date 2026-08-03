//
//  ContentView.swift
//  carbculator
//
//  Created by martin-garrix-L on 8/3/26.
//

import SwiftUI

/// 앱 루트 화면.
/// 기동 시 스플래시를 잠깐 보여준 뒤, 초기 설정(온보딩) 완료 여부에 따라
/// 온보딩 마법사 또는 메인 계산기를 보여준다.
struct ContentView: View {
    @AppStorage(SettingsKeys.isOnboarded) private var isOnboarded = false
    @AppStorage(SettingsKeys.disclaimerHidden) private var disclaimerHidden = false
    @State private var showSplash = true
    @State private var showDisclaimer = false

    var body: some View {
        ZStack {
            mainContent

            if showDisclaimer {
                DisclaimerView(
                    onConfirm: { dismissDisclaimer() },
                    onDontShowAgain: {
                        disclaimerHidden = true
                        dismissDisclaimer()
                    }
                )
                .transition(.opacity)
                .zIndex(1)
            }

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
        .task {
            // 스플래시를 약 1.5초 보여준 뒤 사라지게 하고, 필요하면 면책 팝업을 띄운다.
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            withAnimation(.easeInOut(duration: 0.4)) { showSplash = false }
            if !disclaimerHidden {
                withAnimation(.easeInOut(duration: 0.3)) { showDisclaimer = true }
            }
        }
    }

    private func dismissDisclaimer() {
        withAnimation(.easeInOut(duration: 0.3)) { showDisclaimer = false }
    }

    private var mainContent: some View {
        ZStack {
            if isOnboarded {
                CalculatorView()
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isOnboarded)
    }
}

#Preview {
    ContentView()
}
