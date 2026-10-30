import GameController

#if os(iOS)
import UIKit
#endif

/// Whether to put the caret in a field on arrival (docs/knowledge/app-ui-architecture.md →
/// Windows and keyboard focus). A Mac always has a keyboard and an iPad may. An iPhone's
/// software keyboard covers half the screen, so it opens only when asked.
enum HardwareKeyboard {
    static var isExpected: Bool {
        #if os(macOS)
        true
        #else
        UIDevice.current.userInterfaceIdiom == .pad && GCKeyboard.coalesced != nil
        #endif
    }
}
