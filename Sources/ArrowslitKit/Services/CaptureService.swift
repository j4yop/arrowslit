import AppKit
import Foundation
import Vision

public enum CaptureMode: String, CaseIterable, Sendable {
    case area
    case window
    case fullscreen
    case text
}

@MainActor
public final class CaptureService {
    public struct Result {
        public let image: NSImage
        public let url: URL
        public let mode: CaptureMode
        /// The area in screencapture/Quartz top-left coordinates, when known.
        public let screenRect: CGRect?
    }

    public init() {}

    /// Captures the whole main display. The screenshot is written to a temporary file
    /// so the same path can be edited, copied, or saved by the result bar.
    public func captureFullScreen(includeCursor: Bool = false) throws -> Result {
        let url = try temporaryURL()
        var args = ["-x"]
        if includeCursor { args.append("-C") }
        args.append("-m")
        args.append(url.path)
        try runScreenshot(args)
        guard let image = NSImage(contentsOf: url) else { throw CaptureError.noImage }
        return Result(image: image, url: url, mode: .fullscreen, screenRect: nil)
    }

    public func capture(rect: CGRect, includeCursor: Bool = false) throws -> Result {
        let url = try temporaryURL()
        var args = ["-x"]
        if includeCursor { args.append("-C") }
        args += ["-R", "\(Int(rect.origin.x)),\(Int(rect.origin.y)),\(Int(rect.width)),\(Int(rect.height))", url.path]
        try runScreenshot(args)
        guard let image = NSImage(contentsOf: url) else { throw CaptureError.noImage }
        return Result(image: image, url: url, mode: .area, screenRect: rect)
    }

    public func capture(windowID: CGWindowID, includeCursor: Bool = false) throws -> Result {
        let url = try temporaryURL()
        var args = ["-x"]
        if includeCursor { args.append("-C") }
        args += ["-l", String(windowID), url.path]
        try runScreenshot(args)
        guard let image = NSImage(contentsOf: url) else { throw CaptureError.noImage }
        return Result(image: image, url: url, mode: .window, screenRect: nil)
    }

    /// Crop a source image to a rect in screen coordinates. Used by the area picker.
    public func crop(_ image: NSImage, to rect: CGRect) -> NSImage? {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        guard let cropped = cg.cropping(to: rect) else { return nil }
        return NSImage(cgImage: cropped, size: rect.size)
    }

    public func recognizeText(in image: NSImage) throws -> String {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { throw CaptureError.noImage }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US"]
        try VNImageRequestHandler(cgImage: cg).perform([request])
        let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        return lines.joined(separator: "\n")
    }

    public func paste(_ image: NSImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }

    public func save(_ image: NSImage, to directory: URL) throws -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let url = directory.appendingPathComponent("Arrowslit \(formatter.string(from: Date())).png")
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            throw CaptureError.noImage
        }
        try png.write(to: url)
        return url
    }

    private func temporaryURL() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("ArrowslitCapture", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("capture-\(UUID().uuidString).png")
    }

    private func runScreenshot(_ args: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = args
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw CaptureError.failed }
    }

    public enum CaptureError: LocalizedError {
        case failed, noImage

        public var errorDescription: String? {
            switch self {
            case .failed: "The screen could not be captured."
            case .noImage: "The capture did not produce an image."
            }
        }
    }
}
