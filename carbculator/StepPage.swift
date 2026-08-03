//
//  StepPage.swift
//  carbculator
//
//  스텝 플로우 공통 UI 컴포넌트 모음
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 스텝 전환 애니메이션

extension AnyTransition {
    /// 진행 방향에 따라 페이지를 밀어내는 전환
    static func stepPush(forward: Bool) -> AnyTransition {
        .asymmetric(
            insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)
        )
    }
}

extension Color {
    /// 입력 필드/카드 공통 배경색
    static let cardBackground = Color(.secondarySystemBackground)
}

// MARK: - 공통 페이지 레이아웃

/// 질문(타이틀) + 입력 컨텐츠 + 하단 다음 버튼으로 구성된 스텝 페이지
struct StepPage<Content: View>: View {
    private let title: String
    private let subtitle: String
    private let nextTitle: String
    private let isNextEnabled: Bool
    private let onNext: (() -> Void)?
    private let content: Content

    init(
        title: String,
        subtitle: String,
        nextTitle: String = "다음",
        isNextEnabled: Bool = true,
        onNext: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.nextTitle = nextTitle
        self.isNextEnabled = isNextEnabled
        self.onNext = onNext
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title.bold())
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            content
                .padding(.top, 24)

            Spacer(minLength: 0)

            if let onNext {
                Button(action: onNext) {
                    Text(nextTitle)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!isNextEnabled)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - 숫자 입력 필드

struct NumberInputField: View {
    let placeholder: String
    let unit: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            TextField(placeholder, text: $text)
                .keyboardType(.decimalPad)
                .font(.title3.weight(.semibold))
            Text(unit)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - 선택형 옵션 버튼

struct OptionRowButton: View {
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 안내/경고 박스

struct NoticeBox: View {
    let icon: String
    let text: String
    var tint: Color = .orange

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - 키보드 내리기

extension View {
    func hideKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
        )
        #endif
    }
}
