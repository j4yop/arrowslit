import AppKit
import ArrowslitKit

AgentHookClient.runIfRequested()

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.run()
