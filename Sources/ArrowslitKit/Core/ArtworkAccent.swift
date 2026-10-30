import CoreGraphics
import Foundation
import ImageIO

/// A small, readable accent colour taken from album art. Kept as plain numbers so it can cross
/// the media reader's background queue safely.
public struct ArtworkAccent: Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = min(max(red, 0), 1)
        self.green = min(max(green, 0), 1)
        self.blue = min(max(blue, 0), 1)
    }

    public static let white = ArtworkAccent(red: 1, green: 1, blue: 1)
}

public enum ArtworkAccentReader {
    /// Decodes a small thumbnail and averages the colourful pixels. Grey or unreadable artwork
    /// falls back to white, which is what the notch uses for monochrome covers.
    public static func accent(from data: Data) -> ArtworkAccent {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 32,
            ] as CFDictionary)
        else { return .white }

        let side = 12
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let drew = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: side,
                height: side,
                bitsPerComponent: 8,
                bytesPerRow: side * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.interpolationQuality = .medium
            context.draw(thumbnail, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drew else { return .white }

        var red = 0.0
        var green = 0.0
        var blue = 0.0
        var total = 0.0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = Double(pixels[index + 3]) / 255
            guard alpha > 0.35 else { continue }
            let r = Double(pixels[index]) / 255
            let g = Double(pixels[index + 1]) / 255
            let b = Double(pixels[index + 2]) / 255
            let high = max(r, g, b)
            let low = min(r, g, b)
            let saturation = high - low
            guard saturation > 0.10, high > 0.12 else { continue }
            let weight = 0.25 + saturation
            red += r * weight
            green += g * weight
            blue += b * weight
            total += weight
        }
        guard total > 0 else { return .white }

        var accent = ArtworkAccent(red: red / total, green: green / total, blue: blue / total)
        let high = max(accent.red, max(accent.green, accent.blue))
        if high > 0, high < 0.58 {
            let lift = 0.58 / high
            accent = ArtworkAccent(red: accent.red * lift, green: accent.green * lift, blue: accent.blue * lift)
        }
        return accent
    }
}
