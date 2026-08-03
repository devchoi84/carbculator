<div align="center">

# 🩸 Carb·culator

**Carb**(탄수화물) + cal**culator**(계산기) = **탄수화물 계산기**

### 탄수화물 계수 기반 인슐린 볼러스 계산기
**Carb-ratio based insulin bolus calculator for people with diabetes**

식사 전, 혈당과 식사량만 입력하면 권장 인슐린 양을 계산해 주는 iOS 앱입니다.<br/>
_An iOS app that suggests your meal insulin dose from just your blood glucose and what you're eating._

<p>
  <img alt="Platform" src="https://img.shields.io/badge/platform-iOS-black?logo=apple" />
  <img alt="Swift" src="https://img.shields.io/badge/Swift-5.9%2B-orange?logo=swift" />
  <img alt="UI" src="https://img.shields.io/badge/UI-SwiftUI-blue?logo=swift" />
  <img alt="i18n" src="https://img.shields.io/badge/language-한국어%20%2F%20English-success" />
</p>

</div>

> [!WARNING]
> **의료용 기기가 아닙니다 / Not a medical device.**
> 이 앱의 계산 결과는 **참고용**입니다. 실제 인슐린 투여량은 반드시 담당 의료진의 처방과 지침을 따르세요.
> Results are **for reference only**. Always follow your doctor's prescription and guidance for actual dosing.

---

## 📖 개요 · Overview

인슐린을 사용하는 당뇨인은 매 식사마다 "얼마나 주사해야 할지"를 직접 계산해야 합니다. Carbculator는 이 반복적인 계산을 대신해 줍니다.

1. **처음 한 번** — 온보딩 마법사가 나의 **탄수화물 계수(ICR)**, **인슐린 민감도(ISF)**, **목표 혈당**, **펜 단위**를 잡아줍니다. 수치를 몰라도 평소 식사량·처방·하루 총 인슐린으로 역산할 수 있습니다.
2. **매 식사마다** — 현재 혈당과 식사량(음식 무게 또는 탄수화물 g)을 입력하면, **식사 인슐린 + 교정 인슐린**을 합산해 펜 단위로 안전하게 내림한 **권장 투여량**을 알려줍니다.

People on insulin have to calculate their dose at every meal. Carbculator does that math for you — set your personal factors once, then just enter your glucose and meal each time.

---

## ✨ 주요 기능 · Features

| | |
|---|---|
| 🧮 **스마트 온보딩** | ICR/ISF를 몰라도 4가지 방식(평소 식사 역산·직접 입력·병원 처방·하루 총 인슐린 추정)으로 자동 계산 |
| 🍚 **음식 기반 탄수화물 추정** | 쌀밥·잡곡밥·현미밥·식빵·고구마·감자의 무게(g)만 넣으면 탄수화물을 자동 환산 (식약처 DB 근사치) |
| ⚠️ **저혈당 대응** | 혈당이 낮으면(≤ 70 mg/dL) 교정 인슐린으로 권장량을 **자동 감량**하고 저혈당 주의를 안내 · 결과는 항상 펜 단위로 **내림** 처리 |
| 💉 **교정 인슐린 옵션** | ISF를 모르면 교정 없이 식사 인슐린만 계산 가능 · 언제든 설정에서 켜기/끄기 |
| 🌐 **한국어 / English** | 앱 내 즉시 언어 전환 (시스템 언어와 독립) |
| 🎞️ **단계별 플로우 UI** | 질문 하나씩, 부드러운 페이지 전환으로 입력 부담 최소화 |
| 🔒 **온전한 로컬 저장** | 모든 설정은 `@AppStorage`(UserDefaults)로 기기에만 저장 · 서버·계정·네트워크 없음 |

---

## 🧬 계산 원리 · How the math works

### 핵심 공식 · Core formulas

```
식사 인슐린  Meal bolus       =  탄수화물(g)  ÷  ICR
교정 인슐린  Correction bolus =  (현재 혈당 − 목표 혈당)  ÷  ISF
권장 인슐린  Suggested dose   =  max(0, 식사 인슐린 + 교정 인슐린)  →  펜 단위로 내림
```

- **ICR (Insulin-to-Carb Ratio, 탄수화물 계수)** — 인슐린 1단위가 처리하는 탄수화물의 양(g/U).
- **ISF (Insulin Sensitivity Factor, 인슐린 민감도 지수)** — 인슐린 1단위가 낮추는 혈당(mg/dL).
- 현재 혈당이 목표보다 **낮으면** 교정값이 음수가 되어 식사 인슐린에서 **차감**되고, 합계가 음수면 **0**으로 처리해 과다 투여를 막습니다.
- 최종 결과는 반올림이 아니라 **펜 최소 단위(1 U 또는 0.5 U)로 내림**하여 저혈당 위험을 줄입니다.

### 온보딩에서 쓰는 역산·추정식 · Estimation rules used in onboarding

| 값 | 방식 | 계산식 |
|---|---|---|
| ICR | 평소 식사 역산 | `음식 탄수화물 ÷ 그 식사 인슐린` |
| ICR | 병원 처방 기준 | `처방 탄수화물 ÷ 처방 인슐린` |
| ICR | 하루 총 인슐린(TDD) | **500의 법칙** → `500 ÷ TDD` |
| ISF | 하루 총 인슐린(TDD) | **1800의 법칙** → `1800 ÷ TDD` |
| ISF | ICR 기반 추정 | `ICR × 3.6` _(500·1800 법칙의 비율)_ |

> 추정식은 시작점을 잡기 위한 의학적 근사치입니다. 식후 혈당 반응을 관찰하며 담당 의료진과 함께 조정하세요.

---

## 🗺️ 사용자 흐름 · User flow

```
[ 최초 실행 · First launch ]
  온보딩 마법사 (7단계)
   ① ICR 방식 선택  → ② ICR 입력/계산
   ③ ISF 방식 선택  → ④ ISF 입력/추정   (건너뛰기 가능)
   ⑤ 목표 혈당      → ⑥ 펜 단위        → ⑦ 설정 요약·완료
        │
        ▼  isOnboarded = true (기기에 저장)

[ 이후 매 실행 · Every launch after ]
  메인 계산기 (매 식사)
   ① 현재 혈당 입력
        ▼
   ② 식사량 입력 (음식 무게 또는 탄수화물)
        ▼
   ③ 결과: 권장 인슐린 + 상세 내역
        · 저혈당(≤ 70 mg/dL)이면 교정 인슐린으로 자동 감량 + 저혈당 주의 안내
        · IOB(잔여 인슐린) · 의료 면책 안내 포함

  ⚙️ 설정: 언어 · ICR 수정 · ISF/교정 · 목표혈당 · 펜 단위
```

### 결과 화면에서 알려주는 것 · What the result screen shows
- **권장 인슐린(U)** — 펜 단위로 내림한 최종 값 (크게 강조)
- 계산 원값과 내림 적용 내역
- 섭취 탄수화물 · 식사 인슐린 · 교정 인슐린 **분해 내역**
- ⏱️ **잔여 인슐린(IOB) 경고** — 최근 3~4시간 내 주사 시 중복 투여 주의
- 🩺 **의료 면책 안내** — 실제 투여는 의료진 지침 우선

---

## 🏗️ 프로젝트 구조 · Project structure

```
carbculator/
├─ carbculatorApp.swift      앱 진입점 (@main)
├─ ContentView.swift         루트 분기 — 온보딩 완료 여부로 화면 결정
├─ OnboardingView.swift      최초 설정 마법사 (7단계 · ICR/ISF 역산 로직)
├─ CalculatorView.swift      메인 계산 플로우 + 설정(SettingsView) 화면
├─ ICREditView.swift         설정 내 탄수화물 계수 수정 페이지
├─ InsulinCalculator.swift   ⭐ 순수 계산 엔진 · 음식 DB · 저장 키 · 파싱/표시 확장
├─ Localization.swift        한/영 언어 전환 (AppLanguage.t(ko, en))
└─ StepPage.swift            공통 UI 컴포넌트 (StepPage · NumberInputField ·
                             OptionRowButton · NoticeBox · 전환 애니메이션)
```

### 아키텍처 노트 · Architecture notes
- **순수 SwiftUI + async/await** — Combine 미사용. 상태는 `@State`, 영속 설정은 `@AppStorage`.
- **계산 로직 분리** — `InsulinCalculator`는 UI에 의존하지 않는 순수 함수(enum)로, 테스트·재사용이 쉽습니다.
- **단일 소스 오브 트루스** — ICR·ISF·목표혈당·펜단위·교정여부·언어·온보딩여부를 `SettingsKeys`로 관리하며 온보딩·계산기·설정이 동일 키를 공유합니다.
- **이중언어 처리** — `NSLocalizedString` 대신 경량 `AppLanguage.t(_:_:)` 패턴으로 앱 내 즉시 전환을 지원합니다.

---

## 🚀 시작하기 · Getting started

### 요구 사항 · Requirements
- Xcode 15 이상 · iOS 17+ (SwiftUI)

### 빌드 · Build & run
```bash
git clone https://github.com/devchoi84/carbculator.git
cd carbculator
open carbculator.xcodeproj   # Xcode에서 열기
```
Xcode에서 시뮬레이터나 실기기를 선택하고 **⌘R** 로 실행하세요.

---

## 🍚 음식 탄수화물 기준값 · Carb reference (per 100 g)

| 음식 · Food | 탄수화물 · Carbs |
|---|---|
| 쌀밥 (백미) · White rice | 33 g |
| 잡곡밥 · Multigrain rice | 30 g |
| 현미밥 · Brown rice | 30 g |
| 식빵 · White bread | 50 g |
| 고구마(삶은 것) · Sweet potato (boiled) | 30 g |
| 감자(삶은 것) · Potato (boiled) | 17 g |

<sub>식약처 식품영양성분 DB 기반 근사치 · Approximate values based on the Korean MFDS food nutrition database.</sub>

---

## 🔐 개인정보 · Privacy

Carbculator는 **계정·서버·네트워크 통신이 없습니다.** 입력한 혈당·식사·설정값은 모두 기기 내부(UserDefaults)에만 저장되며 외부로 전송되지 않습니다.

No accounts, no servers, no network. Everything stays on your device.

---

## ⚖️ 면책 조항 · Disclaimer

이 소프트웨어는 교육 및 참고 목적으로 제공되며, 의료 기기나 의학적 조언을 대체하지 않습니다. 인슐린 투여와 관련한 모든 결정은 반드시 자격을 갖춘 의료 전문가와 상의하세요. 개발자는 본 앱 사용으로 인한 결과에 대해 책임지지 않습니다.

This software is provided for educational and reference purposes only and is not a substitute for a medical device or professional medical advice. Always consult a qualified healthcare professional for any decision regarding insulin dosing. The authors assume no liability for outcomes resulting from use of this app.
