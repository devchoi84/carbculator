#!/usr/bin/env swift

//
//  crop_icon.swift
//  carbculator
//
//  AI가 만든 아이콘 이미지에서 바깥의 회색 여백을 제거하고,
//  파란 아이콘 본체만 정사각형(1024×1024)으로 크롭한다.
//
//  사용법: swift scripts/crop_icon.swift <입력_PNG> <출력_PNG>
//

import AppKit

guard CommandLine.arguments.count >= 3 else {
    fatalError("사용법: swift crop_icon.swift <입력> <출력>")
}
let inputPath = CommandLine.arguments[1]
let outputPath = CommandLine.arguments[2]

guard let srcImage = NSImage(contentsOfFile: inputPath),
      let tiff = srcImage.tiffRepresentation,
      let src = NSBitmapImageRep(data: tiff) else {
    fatalError("입력 이미지를 읽을 수 없습니다: \(inputPath)")
}

let w = src.pixelsWide
let h = src.pixelsHigh

// "파란 픽셀" 판정: 파랑이 빨강/초록보다 뚜렷하게 강한 픽셀 = 아이콘 본체
func isBlue(_ x: Int, _ y: Int) -> Bool {
    guard let c = src.colorAt(x: x, y: y) else { return false }
    let r = c.redComponent, g = c.greenComponent, b = c.blueComponent
    return b > 0.45 && b > r + 0.12 && b > g + 0.04
}

// 파란 영역의 경계 상자를 찾는다
var minX = w, minY = h, maxX = 0, maxY = 0
for y in 0..<h {
    for x in 0..<w where isBlue(x, y) {
        if x < minX { minX = x }
        if x > maxX { maxX = x }
        if y < minY { minY = y }
        if y > maxY { maxY = y }
    }
}

guard maxX > minX, maxY > minY else {
    fatalError("파란 아이콘 영역을 찾지 못했습니다.")
}

// 정사각형으로 맞추기: 더 긴 변 기준으로 중심을 잡아 정사각 크롭 박스 계산
let boxW = maxX - minX
let boxH = maxY - minY
let side = max(boxW, boxH)
let cx = (minX + maxX) / 2
let cy = (minY + maxY) / 2
var cropX = cx - side / 2
var cropY = cy - side / 2
// 이미지 밖으로 넘어가지 않도록 보정
cropX = max(0, min(cropX, w - side))
cropY = max(0, min(cropY, h - side))

print("파란 영역 bbox: (\(minX),\(minY))-(\(maxX),\(maxY)) → 크롭 \(side)px @ (\(cropX),\(cropY))")

// 크롭 후 1024×1024로 렌더 (알파 없음)
let target = 1024
guard let outRep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: target, pixelsHigh: target,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
    isPlanar: false, colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0
) else {
    fatalError("출력 비트맵을 만들 수 없습니다.")
}
outRep.size = NSSize(width: target, height: target)

guard let nsCtx = NSGraphicsContext(bitmapImageRep: outRep) else {
    fatalError("컨텍스트 생성 실패")
}
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = nsCtx
nsCtx.imageInterpolation = .high

// 좌표계: NSBitmapImageRep는 좌상단 원점 기준으로 픽셀을 다루지만
// 그리기는 좌하단 원점이므로, 소스에서 잘라낼 영역의 y를 뒤집는다.
let srcRect = NSRect(x: cropX, y: h - cropY - side, width: side, height: side)
let dstRect = NSRect(x: 0, y: 0, width: target, height: target)
srcImage.draw(in: dstRect, from: srcRect, operation: .copy, fraction: 1.0)

NSGraphicsContext.restoreGraphicsState()

guard let png = outRep.representation(using: .png, properties: [:]) else {
    fatalError("PNG 인코딩 실패")
}
try png.write(to: URL(fileURLWithPath: outputPath))
print("✅ 크롭 완료: \(outputPath)")
