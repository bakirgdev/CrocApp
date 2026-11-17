// Window and permission queries the shell has no tool for.
//   window list OWNER   one line per on-screen window of the app named OWNER:
//                       id, layer, title, width, height (tab separated)
//   window scroll OWNER scrolls the content of OWNER's front window to its end
//                       (moves the pointer over it, then posts wheel events)
//   window preflight [accessibility]
//                       exit 1 and name what is missing unless Screen Recording
//                       and Accessibility (only Accessibility with the argument)
//                       are granted to the calling terminal
//   window press APP DESCRIPTION
//                       presses the first button whose accessibility description
//                       is DESCRIPTION in the running app whose executable is APP
//   window select APP IDENTIFIER
//                       selects the list row holding the element whose
//                       accessibility identifier is IDENTIFIER, and exits 1
//                       until a window's title starts with that row's name
//
// press and select drive Device Hub, whose pose buttons (Closed, Partially Open,
// Open, Rotate Right) have no menu items or shortcuts to send instead.
//
// screencapture wants a CGWindowID and nothing in the shell hands one out.
// AppleScript's window ids are AX ids, not CGWindowIDs, so System Events
// cannot supply this even though it sees the same windows.
import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
    exit(1)
}

func axApp(_ executable: String) -> AXUIElement {
    guard
        let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.executableURL?.lastPathComponent == executable
        })
    else { fail("\(executable) is not running") }
    return AXUIElementCreateApplication(app.processIdentifier)
}

func axAttribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
    var value: AnyObject?
    return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success
        ? value : nil
}

/// Depth first, in the order the app lists its children, skipping the menu bar.
func axFind(_ element: AXUIElement, depth: Int = 0, _ match: (AXUIElement) -> Bool)
    -> AXUIElement?
{
    if match(element) { return element }
    guard depth < 40, let children = axAttribute(element, kAXChildrenAttribute) as? [AXUIElement]
    else { return nil }
    for child in children where axAttribute(child, kAXRoleAttribute) as? String != "AXMenuBar" {
        if let found = axFind(child, depth: depth + 1, match) { return found }
    }
    return nil
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
case "scroll" where args.count > 2:
    guard
        let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]],
        let window = list.first(where: {
            $0[kCGWindowOwnerName as String] as? String == args[2]
                && $0[kCGWindowLayer as String] as? Int == 0
        }),
        let bounds = window[kCGWindowBounds as String] as? [String: Any],
        let x = (bounds["X"] as? NSNumber)?.doubleValue,
        let y = (bounds["Y"] as? NSNumber)?.doubleValue,
        let w = (bounds["Width"] as? NSNumber)?.doubleValue,
        let h = (bounds["Height"] as? NSNumber)?.doubleValue
    else { fail("no window of \(args[2]) to scroll") }
    CGWarpMouseCursorPosition(CGPoint(x: x + w / 2, y: y + h / 2))
    for _ in 0..<10 {
        CGEvent(
            scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: -400, wheel2: 0,
            wheel3: 0)?.post(tap: .cghidEventTap)
        usleep(50_000)
    }
case "press" where args.count > 3:
    guard
        let button = axFind(
            axApp(args[2]),
            {
                axAttribute($0, kAXRoleAttribute) as? String == "AXButton"
                    && axAttribute($0, kAXDescriptionAttribute) as? String == args[3]
            })
    else { fail("no button '\(args[3])' in \(args[2])") }
    guard AXUIElementPerformAction(button, kAXPressAction as CFString) == .success else {
        fail("pressing '\(args[3])' in \(args[2]) failed")
    }
case "select" where args.count > 3:
    var row = axFind(axApp(args[2])) {
        axAttribute($0, kAXIdentifierAttribute) as? String == args[3]
    }
    while let element = row, axAttribute(element, kAXRoleAttribute) as? String != "AXRow" {
        row = axAttribute(element, kAXParentAttribute).map { $0 as! AXUIElement }
    }
    guard let row else { fail("no row holding '\(args[3])' in \(args[2])") }
    guard
        AXUIElementSetAttributeValue(row, kAXSelectedAttribute as CFString, kCFBooleanTrue)
            == .success
    else { fail("selecting '\(args[3])' in \(args[2]) failed") }
    // Device Hub can mark a just-booted simulator's row selected without showing
    // it; only the window title, "<name> – <OS>", says what the pose buttons act on.
    let name = axFind(row) { axAttribute($0, kAXRoleAttribute) as? String == "AXStaticText" }
        .flatMap { axAttribute($0, kAXValueAttribute) as? String }
    let windows = axAttribute(axApp(args[2]), kAXWindowsAttribute) as? [AXUIElement] ?? []
    guard let name,
        windows.contains(where: {
            (axAttribute($0, kAXTitleAttribute) as? String)?.hasPrefix("\(name) ") == true
        })
    else { fail("\(args[2]) does not show '\(args[3])' yet") }
case "preflight":
    var missing: [String] = []
    if args.count < 3, !CGPreflightScreenCaptureAccess() { missing.append("Screen Recording") }
    if !AXIsProcessTrusted() { missing.append("Accessibility") }
    if !missing.isEmpty {
        fail("missing: \(missing.joined(separator: ", "))")
    }
default:
    fail(
        "usage: window list OWNER | window scroll OWNER | window press APP DESCRIPTION | window select APP IDENTIFIER | window preflight [accessibility]"
    )
}
