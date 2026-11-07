import AppKit
import AVFoundation
import SwiftUI

struct CameraPreview: NSViewRepresentable {
    var deviceID: String? = nil
    var mirrored = true
    var quality = "high"

    func makeNSView(context: Context) -> CameraPreviewView {
        CameraPreviewView(deviceID: deviceID, mirrored: mirrored, quality: quality)
    }

    func updateNSView(_ nsView: CameraPreviewView, context: Context) {}

    static func dismantleNSView(_ nsView: CameraPreviewView, coordinator: ()) {
        nsView.stop()
    }
}

final class CameraPreviewView: NSView {
    private let session = AVCaptureSession()
    private let previewLayer: AVCaptureVideoPreviewLayer
    private let queue = DispatchQueue(label: "com.j4yop.arrowslit.camera")

    init(deviceID: String?, mirrored: Bool, quality: String) {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        super.init(frame: .zero)
        wantsLayer = true
        layer = CALayer()
        previewLayer.videoGravity = .resizeAspectFill
        layer?.addSublayer(previewLayer)
        configure(deviceID: deviceID, mirrored: mirrored, quality: quality)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer.frame = bounds
        CATransaction.commit()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { stop() } else { start() }
    }

    func stop() {
        nonisolated(unsafe) let session = session
        queue.async {
            if session.isRunning { session.stopRunning() }
        }
    }

    private func start() {
        nonisolated(unsafe) let session = session
        queue.async {
            if !session.isRunning { session.startRunning() }
        }
    }

    private func configure(deviceID: String?, mirrored: Bool, quality: String) {
        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
            mediaType: .video,
            position: .unspecified
        ).devices
        let camera = devices.first(where: { $0.uniqueID == deviceID })
            ?? AVCaptureDevice.default(for: .video)
        guard let camera, let input = try? AVCaptureDeviceInput(device: camera) else { return }
        session.beginConfiguration()
        session.sessionPreset = quality == "low" ? .low : quality == "medium" ? .medium : .high
        if session.canAddInput(input) {
            session.addInput(input)
        }
        session.commitConfiguration()
        if let connection = previewLayer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = mirrored
        }
    }
}
