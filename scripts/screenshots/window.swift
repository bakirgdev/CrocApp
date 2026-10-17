// Window and permission queries the shell has no tool for.
//   window list OWNER   one line per on-screen window of the app named OWNER:
//                       id, layer, title, width, height (tab separated)
//   window preflight    exit 1 and name what is missing unless Screen Recording
//                       and Accessibility are granted to the calling terminal
//
// screencapture wants a CGWindowID and nothing in the shell hands one out.
// AppleScript's window ids are AX ids, not CGWindowIDs, so System Events
// cannot supply this even though it sees the same windows.
import ApplicationServices
import CoreGraphics
import Foundation

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
    exit(1)
}

let args = CommandLine.arguments
switch args.count > 1 ? args[1] : "" {
case "list" where args.count > 2:
    guard
        let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
    else { fail("cannot list windows") }
    for window in list where window[kCGWindowOwnerName as String] as? String == args[2] {
        let number = window[kCGWindowNumber as String] as? Int ?? 0
        let layer = window[kCGWindowLayer as String] as? Int ?? -1
        let name = window[kCGWindowName as String] as? String ?? ""
        let bounds = window[kCGWindowBounds as String] as? [String: Any]
        let width = (bounds?["Width"] as? NSNumber)?.intValue ?? 0
        let height = (bounds?["Height"] as? NSNumber)?.intValue ?? 0
        print("\(number)\t\(layer)\t\(name)\t\(width)\t\(height)")
    }
case "preflight":
    var missing: [String] = []
    if !CGPreflightScreenCaptureAccess() { missing.append("Screen Recording") }
    if !AXIsProcessTrusted() { missing.append("Accessibility") }
    if !missing.isEmpty {
        fail("missing: \(missing.joined(separator: ", "))")
    }
default:
    fail("usage: window list OWNER | window preflight")
}
