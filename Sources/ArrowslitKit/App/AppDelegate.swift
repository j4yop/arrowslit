import AppKit

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var state: AppState?
    private var panel: PanelController?
    private var statusItem: StatusItemController?
    private var settingsWindow: SettingsWindowController?
    #if DEBUG
    private var debugHooks: DebugHooks?
    #endif

    public override init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installMainMenu()
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
        #if DEBUG
        debugHooks = DebugHooks(state: state)
        #endif
        state.start()

        if state.settings.openSettingsOnLaunch {
            DispatchQueue.main.async { [weak settingsWindow] in
                settingsWindow?.show()
            }
        }
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settingsWindow?.show()
        return true
    }

    public func applicationWillTerminate(_ notification: Notification) {
        state?.stop()
        panel?.tearDown()
    }

    private func installMainMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        appItem.title = "Arrowslit"
        let appMenu = NSMenu(title: "Arrowslit")
        let about = NSMenuItem(title: "About Arrowslit", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        appMenu.addItem(about)
        appMenu.addItem(.separator())
        let settings = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        appMenu.addItem(settings)
        appMenu.addItem(.separator())
        let hide = NSMenuItem(title: "Hide Arrowslit", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        hide.target = NSApp
        appMenu.addItem(hide)
        let quit = NSMenuItem(title: "Quit Arrowslit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        appMenu.addItem(quit)
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)

        NSApp.mainMenu = mainMenu
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func showSettings() {
        settingsWindow?.show()
    }

    private func alreadyRunning() -> Bool {
        guard let id = Bundle.main.bundleIdentifier else { return false }
        return NSRunningApplication.runningApplications(withBundleIdentifier: id)
            .contains { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
    }
}
