//
//  AverageColor.swift
//  PDColorKit
//
//  Created by lynnswap on 2025/05/26.
//

import SwiftUI

#if os(iOS) || os(tvOS) || os(watchOS)
import UIKit
public typealias CrossPlatformImage = UIImage
public typealias CrossPlatformColor = UIColor

#elseif os(macOS)
import AppKit
public typealias CrossPlatformImage = NSImage
public typealias CrossPlatformColor = NSColor
#endif
extension CrossPlatformImage {
    /// macOS の NSImage と iOS の UIImage で共通して CGImage を取り出す
    var cgImageExtract: CGImage? {
        #if os(macOS)
        // NSImage の場合
        var rect = CGRect(origin: .zero, size: self.size)
        // macOSでは「ポイントサイズ」なので retina などスケールを考慮したい場合は別途対応が必要
        return self.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        #else
        // iOS/ tvOS / watchOS の場合
        return self.cgImage
        #endif
    }
}
extension CrossPlatformColor {
    /// 他の色と近いかどうかをしきい値で判定
    func isSimilar(to color: CrossPlatformColor, threshold: CGFloat) -> Bool {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        
        self.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        color.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        return abs(r1 - r2) <= threshold
        && abs(g1 - g2) <= threshold
        && abs(b1 - b2) <= threshold
    }
    
    /// 彩度が一定値未満の場合に minimumSaturation まで底上げ
    func with(minimumSaturation: CGFloat) -> CrossPlatformColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
#if os(macOS)
        // NSColor は getHue(_:saturation:brightness:alpha:) が「Void」戻り値
        // なので、単に呼ぶだけでOK（失敗したかどうかは返ってこない）
        
        // まずは RGB 色空間に変換できるかを確認するほうが安全
        // （CMYK や Gray などの NSColor だと正しく HSB を得られない場合がある）
        guard let converted = self.usingColorSpace(.deviceRGB) else {
            // RGB にできない場合は、そのまま返す
            return self
        }
        // converted はRGBなので getHue(...)しても問題なく値が得られる
        converted.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        return CrossPlatformColor(
            hue: hue,
            saturation: max(saturation, minimumSaturation),
            brightness: brightness,
            alpha: alpha
        )
        
#else
        // iOS / watchOS / tvOS の UIColor は Bool を返す
        if self.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
            return CrossPlatformColor(
                hue: hue,
                saturation: max(saturation, minimumSaturation),
                brightness: brightness,
                alpha: alpha
            )
        }
        // 取得できなかった場合はそのまま
        return self
#endif
    }
}
private let grid :Int = 4
public extension CrossPlatformImage {
    /// 1ピクセルに縮小して平均色を取得する
    func averageColor() -> CrossPlatformColor? {
        guard let cg = cgImageExtract else { return nil }
        
        let width = 1
        let height = 1
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
                      | CGBitmapInfo.byteOrder32Big.rawValue

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 4 * width,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }
        
        // 1x1 へ描画
        context.draw(cg, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        
        // ピクセルバッファを取り出し RGBA を取得
        guard let pixelBuffer = context.data else { return nil }
        let pixelData = pixelBuffer.bindMemory(to: UInt8.self, capacity: 4)
        
        let red   = CGFloat(pixelData[0]) / 255.0
        let green = CGFloat(pixelData[1]) / 255.0
        let blue  = CGFloat(pixelData[2]) / 255.0
        let alpha = CGFloat(pixelData[3]) / 255.0
        
        return CrossPlatformColor(red: red, green: green, blue: blue, alpha: alpha)
    }
    
    /// grid x grid に縮小して、その各ピクセル色（=ドミナントカラー候補）を取得
    func dominantColorsFast(grid: Int) -> [CrossPlatformColor] {
        guard let cg = cgImageExtract else { return [] }
        
        // grid x grid のビットマップコンテキストを作成
        let width = grid
        let height = grid
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return []
        }
        
        let drawRect = CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
        context.draw(cg, in: drawRect)
        
        guard let data = context.data else {
            return []
        }
        
        var colors: [CrossPlatformColor] = []
        let pixelBuffer = data.bindMemory(to: UInt8.self, capacity: width * height * bytesPerPixel)
        
        for row in 0..<height {
            for col in 0..<width {
                let offset = (row * bytesPerRow) + (col * bytesPerPixel)
                let r = CGFloat(pixelBuffer[offset + 0]) / 255.0
                let g = CGFloat(pixelBuffer[offset + 1]) / 255.0
                let b = CGFloat(pixelBuffer[offset + 2]) / 255.0
                let a = CGFloat(pixelBuffer[offset + 3]) / 255.0
                
                let color = CrossPlatformColor(red: r, green: g, blue: b, alpha: a)
                colors.append(color)
            }
        }
        
        return colors
    }
}

public extension CrossPlatformImage {
    func generateCorrectedColor(grid: Int = 4) -> Color {
        let dominantColorsList = self.dominantColorsFast(grid: grid)
        guard let mostFrequent = mostFrequentColor(colors: dominantColorsList, threshold: 0.1) else {
            return Color.clear
        }
        let correctedColor = mostFrequent.with(minimumSaturation: 0.15)
        
        // NSColor or UIColor を SwiftUI.Color に変換
        return Color(correctedColor)
    }
}
func mostFrequentColor(
    colors: [CrossPlatformColor],
    threshold: CGFloat = 0.1
) -> CrossPlatformColor? {
    var colorFrequency: [CrossPlatformColor: Int] = [:]
    
    for color in colors {
        var matched = false
        
        for (existingColor, _) in colorFrequency {
            if color.isSimilar(to: existingColor, threshold: threshold) {
                colorFrequency[existingColor, default: 0] += 1
                matched = true
                break
            }
        }
        
        if !matched {
            colorFrequency[color] = 1
        }
    }
    
    return colorFrequency.max { a, b in a.value < b.value }?.key
}
