import Foundation
import Testing
@testable import ArrowslitKit

@Suite("Vorssaint audio and notifications")
struct VorssaintAudioNotificationTests {
    @Test func mixerGainAndSliderPositionsRoundTrip() {
        for volume in [0.0, 0.25, 0.5, 1.0, 1.5, 2.0] {
            let gain = MixerRoutingSupport.gain(forVolume: volume)
            let back = MixerRoutingSupport.volume(forGain: Double(gain))
            #expect(abs(back - volume) < 0.001)
        }
    }

    @Test func notificationInboxPrimesBeforeArrivals() {
        let first = NotchSystemNotification(
            id: UUID(),
            content: NotchNotificationContent(app: "Mail", title: "Hello", subtitle: "", body: "One new message"),
            received: Date(),
            canOpen: true
        )
        let second = NotchSystemNotification(
            id: UUID(),
            content: NotchNotificationContent(app: "Calendar", title: "Standup", subtitle: "10:00", body: "In 5 minutes"),
            received: Date(),
            canOpen: true
        )
        var inbox = NotchNotificationInbox()
        #expect(inbox.update([first]).isEmpty)
        #expect(inbox.items.isEmpty)
        #expect(inbox.update([first, second]).map(\.id) == [second.id])
        #expect(inbox.items.count == 1)
        #expect(inbox.items.map(\.id) == [second.id])
        inbox.dismiss(second.id)
        #expect(inbox.items.isEmpty)
        inbox.clear()
        #expect(inbox.items.isEmpty)
    }

    @Test func notificationContentKeepsFieldsSeparate() {
        let content = NotchNotificationContent(
            app: "Messages",
            title: "Piyush",
            subtitle: "now",
            body: "See you at 8"
        )
        #expect(content.compactTitle == "Piyush")
        #expect(content.compactDetail == "now · See you at 8")
        #expect(content.accessibilityText == "Messages, Piyush, now, See you at 8")
    }
}
