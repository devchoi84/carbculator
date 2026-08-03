//
//  SplashView.swift
//  carbculator
//
//  앱 기동 시 흰 배경에 로고를 잠깐 보여주는 타이틀(스플래시) 화면.
//

import SwiftUI

struct SplashView: View {
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 132, height: 132)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
                .scaleEffect(appeared ? 1.0 : 0.92)
                .opacity(appeared ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.4), value: appeared)
        }
        .onAppear { appeared = true }
    }
}

#Preview {
    SplashView()
}
