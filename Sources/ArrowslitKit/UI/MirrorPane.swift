import SwiftUI

struct MirrorPane: View {
    @Bindable var state: AppState
    private var camera: CameraAccess { state.camera }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("MIRROR")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(ArrowTheme.faint)
                    Text("A quick look before a call. Nothing is recorded.")
                        .font(.system(size: 11))
                        .foregroundStyle(ArrowTheme.muted)
                }
                Spacer()
                if camera.state == .granted {
                    Text("CAMERA")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(ArrowTheme.green)
                }
            }

            switch camera.state {
            case .notAsked:
                prompt(
                    symbol: "person.crop.square",
                    message: "Arrowslit can show a local camera preview. The camera turns off when you leave this tab.",
                    button: "Turn On Camera"
                ) { camera.request() }
            case .denied:
                prompt(
                    symbol: "camera.slash",
                    message: "Camera access is off for Arrowslit.",
                    button: "Open Privacy Settings"
                ) { camera.openPrivacySettings() }
            case .noCamera:
                prompt(
                    symbol: "video.slash",
                    message: "No camera found on this Mac.",
                    button: nil
                ) {}
            case .granted:
                HStack(spacing: 18) {
                    Group {
                        if camera.isCameraOff {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(ArrowTheme.panel)
                                Image(systemName: "camera.slash")
                                    .font(.system(size: 28, weight: .light))
                                    .foregroundStyle(ArrowTheme.faint)
                            }
                        } else {
                            CameraPreview()
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .frame(maxWidth: 380, maxHeight: .infinity)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(camera.isCameraOff ? "Camera preview is off." : "Check how you look, then close this tab.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(ArrowTheme.bone)
                            .fixedSize(horizontal: false, vertical: true)
                        Button(camera.isCameraOff ? "Turn On Camera" : "Turn Off Camera") {
                            camera.toggle()
                        }
                        .buttonStyle(NookPressStyle())
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ArrowTheme.ink)
                        .padding(.horizontal, 15)
                        .frame(height: 32)
                        .background(Capsule().fill(ArrowTheme.amber))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .onAppear { camera.refresh() }
    }

    private func prompt(symbol: String, message: String, button: String?, action: @escaping () -> Void) -> some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(ArrowTheme.faint)
            Text(message)
                .font(.system(size: 11.5))
                .foregroundStyle(ArrowTheme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            if let button {
                Button(button, action: action)
                    .buttonStyle(NookPressStyle())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ArrowTheme.ink)
                    .padding(.horizontal, 15)
                    .frame(height: 32)
                    .background(Capsule().fill(ArrowTheme.amber))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
