//
//  AverageColor.swift
//  PDColorKit
//
//  Created by lynnswap on 2025/05/26.
//

import SwiftUI

#if canImport(UIKit)
typealias CrossPlatformImage = UIImage
typealias CrossPlatformColor = UIColor

#elseif canImport(AppKit)
typealias CrossPlatformImage = NSImage
typealias CrossPlatformColor = NSColor
#endif
extension CrossPlatformImage {
    var cgImageExtract: CGImage? {
#if canImport(AppKit)
        var rect = CGRect(origin: .zero, size: self.size)
        // macOSでは「ポイントサイズ」なので retina などスケールを考慮したい場合は別途対応が必要
        return self.cgImage(forProposedRect: &rect, context: nil, hints: nil)
#else
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
        
#if canImport(AppKit)
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
extension CrossPlatformImage {
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
        context.interpolationQuality = .none
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
    func scaledTo(maxSide: Int) -> CrossPlatformImage? {
        guard let cg = cgImageExtract else { return nil }

        let width = CGFloat(cg.width)
        let height = CGFloat(cg.height)
        let maxLength = max(width, height)

        let ratio = min(CGFloat(maxSide) / maxLength, 1)
        let targetWidth = Int(width * ratio)
        let targetHeight = Int(height * ratio)

        guard let context = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: cg.bitsPerComponent,
            bytesPerRow: 0,
            space: cg.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: cg.bitmapInfo.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .none
        context.draw(cg, in: CGRect(x: 0, y: 0, width: CGFloat(targetWidth), height: CGFloat(targetHeight)))

        guard let scaledCG = context.makeImage() else { return nil }

#if canImport(AppKit)
        return CrossPlatformImage(cgImage: scaledCG, size: NSSize(width: targetWidth, height: targetHeight))
#else
        return CrossPlatformImage(cgImage: scaledCG)
#endif
    }
}

public extension CrossPlatformImage {
    func generateCorrectedColor(grid: Int = 9) -> Color {
        let dominantColorsList = self.dominantColorsFast(grid: grid)
        guard let mostFrequent = mostFrequentColor(colors: dominantColorsList, threshold: 0.1) else {
            return Color.clear
        }
        return Color(mostFrequent)
    }
    func generateCorrectedBottomColor(
        bottom height: Int = 100,
        maxWidth: Int? = nil
    ) -> Color {
        guard let cg = cgImageExtract, height > 0 else { return .clear }
        let clampedHeight = min(height, cg.height)
        let clampedWidth  = maxWidth.map { min($0, cg.width) } ?? cg.width
        
        let originX = (cg.width - clampedWidth) / 2
        let originY = cg.height - clampedHeight
        
        guard let croppedCG = cg.cropping(to: CGRect(
            x: originX,
            y: originY,
            width: clampedWidth,
            height: clampedHeight
        )) else { return .clear }
        
        guard let ctx = CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return .clear }
        
        ctx.interpolationQuality = .none
        ctx.draw(croppedCG, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        
        guard let pixelBuffer = ctx.data else { return .clear }
        let p = pixelBuffer.bindMemory(to: UInt8.self, capacity: 4)
        
        return Color(
            CrossPlatformColor(
                red:   CGFloat(p[0]) / 255.0,
                green: CGFloat(p[1]) / 255.0,
                blue:  CGFloat(p[2]) / 255.0,
                alpha: CGFloat(p[3]) / 255.0
            )
        )
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
private extension CrossPlatformColor {
    /// sRGB で正規化された RGBA (0‥1) を返す
    /// 取得に失敗したら `nil`
    func sRGBComponents() -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)? {
#if canImport(UIKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if getRed(&r, green: &g, blue: &b, alpha: &a) {
            return (r, g, b, a)
        }
        guard let cgSRGB = cgColor.converted(
                    to: CGColorSpace(name: CGColorSpace.sRGB)!,
                    intent: .defaultIntent,
                    options: nil
                ),
              let comps = cgSRGB.components, comps.count >= 3 else {
            return nil
        }
        return (comps[0], comps[1], comps[2], cgSRGB.alpha)
        
#else
        guard let srgb = usingColorSpace(.sRGB) else { return nil }
        return (srgb.redComponent, srgb.greenComponent, srgb.blueComponent, srgb.alphaComponent)
#endif
    }
}

public extension Color {
    func isLight(threshold: CGFloat = 0.70) -> Bool {
        guard let comps = CrossPlatformColor(self).sRGBComponents() else {
            return false
        }
        func linear(_ c: CGFloat) -> CGFloat {
            c <= 0.03928 ? c / 12.92
                         : pow((c + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * linear(comps.r)
                       + 0.7152 * linear(comps.g)
                       + 0.0722 * linear(comps.b)
        return luminance > threshold
    }
}
