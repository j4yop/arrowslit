import AppKit

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var state: AppState?
    private var panel: PanelController?
    private var statusItem: StatusItemController?
    private var settingsWindow: SettingsWindowController?

    public override init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if alreadyRunning() {
            NSApp.terminate(nil)
            return
        }

        let state = AppState()
        let settingsWindow = SettingsWindowController(state: state)
        state.onOpenSettings = { [weak settingsWindow] in settingsWindow?.show() }

        self.state = state
        self.settingsWindow = settingsWindow
        panel = PanelController(state: state)
        statusItem = StatusItemController(state: state) { [weak settingsWindow] in settingsWindow?.show() }
        state.start()
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settingsWindow?.show()
        return true
    }

    public func applicationWillTerminate(_ notification: Notification) {
        state?.stop()
        panel?.tearDown()
    }

    private func alreadyRunning() -> Bool {
        guard let id = Bundle.main.bundleIdentifier else { return false }
        return NSRunningApplication.runningApplications(withBundleIdentifier: id)
            .contains { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
    }
}
