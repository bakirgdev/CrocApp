import SwiftUI
import UniformTypeIdentifiers

/// Receive flow (F4 code entry, F6 QR scan + paste, F7 output folder).
struct ReceiveView: View {
    @Environment(TransferController.self) private var controller
    @Environment(OutputFolderStore.self) private var outputFolder

    @State private var code = ""
    @State private var showScanner = false
    @State private var showFolderPicker = false

    var body: some View {
        Group {
            if controller.isActive {
                TransferStatusView()
            } else {
                form
            }
        }
        .navigationTitle("Receive")
    }

    private var form: some View {
        VStack(spacing: 16) {
            HStack {
                TextField("Code phrase", text: $code)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                PasteButton(payloadType: String.self) { strings in
                    if let pasted = strings.first {
                        Task { @MainActor in
                            code = Self.extractCode(from: pasted) ?? code
                        }
                    }
                }
                .labelStyle(.iconOnly)
            }

            #if os(iOS)
            Button {
                showScanner = true
            } label: {
                Label("Scan QR Code", systemImage: "qrcode.viewfinder")
            }
            .sheet(isPresented: $showScanner) {
                QRScannerSheet { payload in
                    if let scanned = Self.extractCode(from: payload) {
                        code = scanned
                    }
                    showScanner = false
                }
            }
            #endif

            HStack {
                Label {
                    Text(outputFolder.isUserSelected ? outputFolder.url.lastPathComponent : "Documents")
                        .lineLimit(1)
                        .truncationMode(.middle)
                } icon: {
                    Image(systemName: "folder")
                }
                Spacer()
                Button("Change") { showFolderPicker = true }
                    .fileImporter(isPresented: $showFolderPicker,
                                  allowedContentTypes: [.folder]) { result in
                        if case .success(let url) = result {
                            outputFolder.select(url)
                        }
                    }
                if outputFolder.isUserSelected {
                    Button("Reset") { outputFolder.resetToDefault() }
                }
            }
            .font(.callout)

            Button {
                controller.startReceive(code: code.trimmingCharacters(in: .whitespacesAndNewlines),
                                        into: outputFolder.url,
                                        folderIsScoped: outputFolder.isUserSelected)
            } label: {
                Label("Receive", systemImage: "arrow.down.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).count < 6)
        }
        .padding()
        .frame(maxWidth: 480)
    }

    /// Accepts a bare code, a "croc://<code>" deeplink (our QR payload), or
    /// clipboard noise around either. Returns nil when nothing code-like.
    static func extractCode(from raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = trimmed.range(of: "croc://") {
            let candidate = String(trimmed[range.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return candidate.count >= 6 ? candidate : nil
        }
        guard trimmed.count >= 6, !trimmed.contains(where: \.isWhitespace) else { return nil }
        return trimmed
    }
}
