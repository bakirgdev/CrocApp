import CrocKit
import SwiftUI

/// The result of a Send as Link: the link, its QR, Copy and Share, and Revoke
/// (components.md → StatusBlock). Revoke is here for every link, so one sent
/// with Save Transfer History off, which History never lists, can be revoked.
struct StoredLinkView: View {
    @Environment(TransferController.self) private var controller
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let receipt: StoredReceipt

    @State private var confirmsRevoke = false
    @State private var isRevoking = false
    @State private var revoked = false
    @State private var revokeFailure: String?

    var body: some View {
        ZStack {
            if revoked {
                VStack(spacing: 16) {
                    StatusBlock(
                        kind: .neutral, title: String(localized: "Link revoked"),
                        detail: String(localized: "It no longer works for anyone."))
                    resultAction("Done") { controller.reset() }
                }
                .transition(.opacity)
            } else {
                ready.transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .default, value: revoked)
        .confirmationDialog("Revoke this link?", isPresented: $confirmsRevoke) {
            Button("Revoke Link", role: .destructive) { revoke() }
        } message: {
            Text(
                "The files are deleted from the link server and the link stops working for everyone."
            )
        }
        .alert("Couldn't revoke the link", isPresented: revokeFailureShown) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(revokeFailure ?? "")
        }
    }

    private var ready: some View {
        VStack(spacing: 16) {
            StatusBlock(receipt: receipt)
            QRCodeView(content: receipt.link, label: "QR code for the link")
            Text(receipt.link)
                .font(.caption.monospaced())
                .lineLimit(3)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .accessibilityLabel("Link")
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) { linkActions }
                VStack { linkActions }
            }
            if !controller.storedReceiptSaved {
                StatusBanner(
                    kind: .warning,
                    title: String(localized: "Revoke works only until CrocApp quits"),
                    detail: String(
                        localized:
                            "This device couldn't save the link to the Keychain, so revoke it before you quit if you want it ended early."
                    ))
            }
            Text(revokeNote)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            VStack {
                resultAction(role: .destructive) {
                    confirmsRevoke = true
                } label: {
                    // The label stays, the spinner takes the glyph's place.
                    Label {
                        Text("Revoke Link")
                    } icon: {
                        if isRevoking { ProgressView().controlSize(.small) }
                    }
                    .foregroundStyle(.red)
                }
                .disabled(isRevoking)
                resultAction("Done") { controller.reset() }
                    .disabled(isRevoking)
            }
        }
    }

    @ViewBuilder private var linkActions: some View {
        CopyButton("Copy Link") { Clipboard.copySecret(receipt.link, thisDeviceOnly: true) }
        if let url = URL(string: receipt.link) {
            ShareLink(item: url) {
                Label("Share Link", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.glass)
        }
    }

    /// History lists the link only while Save Transfer History is on.
    private var revokeNote: LocalizedStringKey {
        controller.settings.saveTransferHistory
            ? "Anyone who gets this link can download the files until it expires or runs out. You can also revoke it later in History."
            : "Anyone who gets this link can download the files until it expires or runs out. With Save Transfer History off, this screen is the only place to revoke it."
    }

    private var revokeFailureShown: Binding<Bool> {
        Binding(get: { revokeFailure != nil }, set: { if !$0 { revokeFailure = nil } })
    }

    private func revoke() {
        isRevoking = true
        Task {
            defer { isRevoking = false }
            do {
                try await controller.revoke(receipt)
                revoked = true
            } catch {
                revokeFailure = TransferFailure.revokeText(for: error)
            }
        }
    }
}
