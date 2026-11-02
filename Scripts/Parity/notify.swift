import Foundation
DistributedNotificationCenter.default().postNotificationName(
    Notification.Name("Arrowslit.debug"),
    object: CommandLine.arguments.dropFirst().first ?? "parity-reset",
    userInfo: nil,
    deliverImmediately: true
)
