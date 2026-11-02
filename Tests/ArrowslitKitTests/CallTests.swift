import Testing
@testable import ArrowslitKit

@Suite("Call classification")
struct CallClassifierTests {
    @Test func recognisesTheCallApps() {
        #expect(CallClassifier.isCallApp("com.apple.FaceTime"))
        #expect(CallClassifier.isCallApp("us.zoom.xos"))
        #expect(CallClassifier.isCallApp("com.microsoft.teams2"))
        #expect(!CallClassifier.isCallApp("com.apple.Terminal"))
    }

    @Test func neverTreatsDictationAsACall() {
        #expect(CallClassifier.shouldIgnore("com.apple.SpeechRecognitionCore"))
        #expect(CallClassifier.shouldIgnore("com.apple.siri"))
        #expect(CallClassifier.shouldIgnore("com.apple.dictation"))
        #expect(!CallClassifier.shouldIgnore("com.apple.FaceTime"))
    }

    @Test func mapsBrowserHelpersBackToTheBrowser() {
        #expect(CallClassifier.appBundleIdentifier(forHelper: "com.google.Chrome.helper") == "com.google.Chrome")
        #expect(CallClassifier.appBundleIdentifier(forHelper: "com.google.Chrome.helper.Renderer") == "com.google.Chrome")
        #expect(CallClassifier.appBundleIdentifier(forHelper: "com.apple.Safari") == "com.apple.Safari")
    }
}

@Suite("Call hang-up")
struct CallHangupTests {
    @Test func offersOnlySafeAppRoutes() {
        #expect(CallHangup.route(for: "com.microsoft.teams") != nil)
        #expect(CallHangup.route(for: "us.zoom.xos") != nil)
        #expect(CallHangup.route(for: "Cisco-Systems.Spark") != nil)
        #expect(CallHangup.route(for: "net.whatsapp.WhatsApp") == .accessibilityButton)
        #expect(CallHangup.route(for: "com.apple.FaceTime") == nil)
        #expect(CallHangup.route(for: nil) == nil)
    }

    @Test func whatsAppMicIsOnlyACallWhenItIs() {
        #expect(CallHangup.isWhatsAppOnCall(cameraOn: true, canReadWindows: true, callWindowOpen: false))
        #expect(CallHangup.isWhatsAppOnCall(cameraOn: false, canReadWindows: true, callWindowOpen: true))
        #expect(!CallHangup.isWhatsAppOnCall(cameraOn: false, canReadWindows: true, callWindowOpen: false))
        #expect(CallHangup.isWhatsAppOnCall(cameraOn: false, canReadWindows: false, callWindowOpen: nil))
    }

    @Test func whatsAppEndCallLabelsIgnoreDirectionMarks() {
        #expect(CallHangup.isWhatsAppEndCallLabel("End call"))
        #expect(CallHangup.isWhatsAppEndCallLabel("\u{200E}End call\u{200F}"))
        #expect(CallHangup.isWhatsAppEndCallLabel("Leave call"))
        #expect(!CallHangup.isWhatsAppEndCallLabel("End call and archive"))
    }
}
