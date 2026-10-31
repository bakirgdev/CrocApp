import AppIntents
import SwiftUI
import WidgetKit

/// Control Center (iOS 26, macOS 26) buttons. Each opens CrocApp on its screen
/// through the same intents the widget buttons use.
struct SendControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.bakirgdev.CrocApp.control.send") {
            ControlWidgetButton(action: OpenSendIntent()) {
                Label("Send", systemImage: "arrow.up.circle")
            }
        }
        .displayName("Send with CrocApp")
        .description("Opens CrocApp on Send.")
    }
}

struct ReceiveControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.bakirgdev.CrocApp.control.receive") {
            ControlWidgetButton(action: OpenReceiveIntent()) {
                Label("Receive", systemImage: "arrow.down.circle")
            }
        }
        .displayName("Receive with CrocApp")
        .description("Opens CrocApp on Receive.")
    }
}
