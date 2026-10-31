import SwiftUI
import WidgetKit

@main
struct CrocWidgetsBundle: WidgetBundle {
    var body: some Widget {
        LastTransferWidget()
        SendControl()
        ReceiveControl()
    }
}
