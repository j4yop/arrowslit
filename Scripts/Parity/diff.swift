import AppKit
import Foundation

func load(_ path: String) -> CGImage? {
    guard let image = NSImage(contentsOfFile: path) else { return nil }
    var rect = NSRect(origin: .zero, size: image.size)
    return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
}

func pixels(_ image: CGImage) -> [UInt8] {
    let width = image.width
    let height = image.height
    var data = [UInt8](repeating: 0, count: width * height * 4)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    data.withUnsafeMutableBytes { raw in
        let context = CGContext(
            data: raw.baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        context?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    }
    return data
}

let args = CommandLine.arguments
guard args.count == 3,
      let a = load(args[1]), let b = load(args[2]) else {
    FileHandle.standardError.write(Data("usage: parity-diff old.png new.png\n".utf8))
    exit(2)
}
guard a.width == b.width, a.height == b.height else {
    print("SIZE_MISMATCH \(a.width)x\(a.height) \(b.width)x\(b.height)")
    exit(1)
}
let pa = pixels(a)
let pb = pixels(b)
var maxAlpha = 0
var changedAlpha = 0
var maxRGB = 0
for i in stride(from: 0, to: pa.count, by: 4) {
    let da = abs(Int(pa[i + 3]) - Int(pb[i + 3]))
    if da > maxAlpha { maxAlpha = da }
    if da > 8 { changedAlpha += 1 }
    for channel in 0..<3 {
        let d = abs(Int(pa[i + channel]) - Int(pb[i + channel]))
        if d > maxRGB { maxRGB = d }
    }
}
let total = a.width * a.height
let percent = Double(changedAlpha) / Double(total) * 100
print(String(format: "SIZE %dx%d ALPHA_MAX %d ALPHA_CHANGED %.3f%% RGB_MAX %d", a.width, a.height, maxAlpha, percent, maxRGB))
exit(maxAlpha <= 8 && percent < 1 ? 0 : 1)
