import Foundation
import Testing

@testable import CrocApp

/// Staging from outside the Send screen (Services, Send Clipboard): it opens
/// Send and stages, and never navigates while a transfer is running.
@MainActor @Suite struct AppRouterPendingTests {
    @Test func textIsStagedAndSendOpens() {
        let router = AppRouter()
        router.openSend(text: "hello")
        #expect(router.pendingSendText == "hello")
        #expect(router.path == [.send])
    }
}
