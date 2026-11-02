import CoreGraphics
import Foundation
let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
for window in windows {
    guard (window[kCGWindowOwnerName as String] as? String) == "Arrowslit",
          let bounds = window[kCGWindowBounds as String] as? [String: Any],
          let id = window[kCGWindowNumber as String] as? Int,
          let width = bounds["Width"] as? Int,
          let height = bounds["Height"] as? Int,
          let y = bounds["Y"] as? Int,
          width >= 240, y <= 8 else { continue }
    print("\(id) \(width) \(height)")
    exit(0)
}
exit(1)
