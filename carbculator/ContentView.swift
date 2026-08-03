//
//  ContentView.swift
//  carbculator
//
//  Created by martin-garrix-L on 8/3/26.
//

import SwiftUI

/// 앱 루트 화면.
/// 초기 설정(온보딩) 완료 여부에 따라 온보딩 마법사 또는 메인 계산기를 보여준다.
/// 추후 타이틀(스플래시) 페이지는 이 분기 앞 단계로 추가하면 된다.
struct ContentView: View {
    @AppStorage(SettingsKeys.isOnboarded) private var isOnboarded = false

    var body: some View {
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
