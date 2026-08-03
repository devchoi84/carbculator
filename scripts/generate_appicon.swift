#!/usr/bin/env swift

//
//  generate_appicon.swift
//  carbculator
//
//  1024×1024 앱 아이콘(임시)을 코드로 생성한다.
//  파란 그라데이션 배경 위에 흰색 물방울(SF Symbol: drop.fill)을 얹은 형태.
//
//  사용법: swift scripts/generate_appicon.swift <출력_PNG_경로>
//

import AppKit

let side: CGFloat = 1024

// 출력 경로 (인자로 받거나 기본값 사용)
let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "AppIcon-1024.png"

// 정확히 1024×1024 픽셀 비트맵을 만든다. (Retina 백킹 스케일 영향을 받지 않도록
// NSImage.lockFocus 대신 고정 크기 비트맵 rep에 직접 그린다.)
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(side),
    pixelsHigh: Int(side),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fatalError("비트맵을 만들 수 없습니다.")
}
rep.size = NSSize(width: side, height: side)

guard let nsCtx = NSGraphicsContext(bitmapImageRep: rep) else {
    fatalError("그래픽 컨텍스트를 만들 수 없습니다.")
}
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = nsCtx
let ctx = nsCtx.cgContext

// 1) 배경 그라데이션 (좌상단 밝은 파랑 → 우하단 진한 인디고)
let colors = [
    NSColor(calibratedRed: 0.30, green: 0.55, blue: 1.00, alpha: 1).cgColor,
    NSColor(calibratedRed: 0.05, green: 0.20, blue: 0.75, alpha: 1).cgColor
] as CFArray
if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                             colors: colors, locations: [0, 1]) {
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: side),
        end: CGPoint(x: side, y: 0),
        options: []
    )
}

// 2) 중앙에 흰색 물방울(teardrop)을 베지어 경로로 직접 그린다.
//    아래쪽은 둥근 원, 위쪽은 뾰족한 꼭짓점 형태. (좌표계 원점: 좌하단, y는 위로 증가)
let cx = side / 2
let r: CGFloat = 205          // 물방울 아랫부분 원의 반지름
let bulbY: CGFloat = 400      // 원의 중심 y
let tipY: CGFloat = 745       // 물방울 꼭짓점 y

let drop = NSBezierPath()
drop.move(to: NSPoint(x: cx, y: tipY))                    // 위 꼭짓점
// 오른쪽 곡선: 꼭짓점 → 원의 오른쪽 끝
drop.curve(to: NSPoint(x: cx + r, y: bulbY),
           controlPoint1: NSPoint(x: cx + r * 0.30, y: tipY - (tipY - bulbY) * 0.30),
           controlPoint2: NSPoint(x: cx + r, y: bulbY + r * 0.80))
// 아래쪽 반원: 오른쪽 끝 → (바닥 경유) → 왼쪽 끝
drop.appendArc(withCenter: NSPoint(x: cx, y: bulbY), radius: r,
               startAngle: 0, endAngle: 180, clockwise: true)
// 왼쪽 곡선: 원의 왼쪽 끝 → 꼭짓점
drop.curve(to: NSPoint(x: cx, y: tipY),
           controlPoint1: NSPoint(x: cx - r, y: bulbY + r * 0.80),
           controlPoint2: NSPoint(x: cx - r * 0.30, y: tipY - (tipY - bulbY) * 0.30))
drop.close()

NSColor.white.setFill()
drop.fill()

NSGraphicsContext.restoreGraphicsState()

// 3) PNG로 저장 (알파 없는 rep 그대로 인코딩)
guard let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("PNG 인코딩에 실패했습니다.")
}

do {
    try png.write(to: URL(fileURLWithPath: outputPath))
    print("✅ 아이콘 생성 완료: \(outputPath)")
} catch {
    fatalError("파일 저장 실패: \(error)")
}
