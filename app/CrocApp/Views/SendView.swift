import SwiftUI
import UniformTypeIdentifiers

/// Send flow (F1 files, F2 folders, F3 text/clipboard, F5 custom code).
struct SendView: View {
    @Environment(TransferController.self) private var controller

    enum Mode: String, CaseIterable { case files = "Files", text = "Text" }

    @State private var mode: Mode = .files
    @State private var pickedURLs: [URL] = []
    @State private var text = ""
    @State private var customCode = ""
    @State private var showFileImporter = false
    @State private var showFolderImporter = false
    @State private var isDropTargeted = false

    var body: some View {
        Group {
            if controller.isActive {
                TransferStatusView()
            } else {
                form
            }
        }
        .navigationTitle("Send")
    }

    private var form: some View {
        VStack(spacing: 16) {
            Picker("What to send", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { Text($0.rawValue) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if mode == .files {
                filesSection
            } else {
                textSection
            }

            TextField("Custom code (optional, at least 6 characters)", text: $customCode)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif

            Button {
                if mode == .files {
                    controller.startSend(urls: pickedURLs, customCode: customCode.trimmingCharacters(in: .whitespaces))
                } else {
                    controller.startSendText(text, customCode: customCode.trimmingCharacters(in: .whitespaces))
                }
            } label: {
                Label("Send", systemImage: "arrow.up.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canStart)
        }
        .padding()
        .frame(maxWidth: 480)
    }

    private var canStart: Bool {
        let codeOK = customCode.isEmpty || customCode.trimmingCharacters(in: .whitespaces).count >= 6
        let payloadOK = mode == .files ? !pickedURLs.isEmpty : !text.isEmpty
        return codeOK && payloadOK
    }

    // MARK: - Files

    private var filesSection: some View {
        VStack(spacing: 12) {
            Group {
                if pickedURLs.isEmpty {
                    ContentUnavailableView("Drop files or folders here",
                                           systemImage: "square.and.arrow.up.on.square",
                                           description: Text("or add them with the buttons below"))
                } else {
                    List {
                        ForEach(pickedURLs, id: \.self) { url in
                            HStack {
                                Image(systemName: url.hasDirectoryPath ? "folder" : "doc")
                                Text(url.lastPathComponent)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Button {
                                    pickedURLs.removeAll { $0 == url }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .frame(minHeight: 160, maxHeight: 280)
            .overlay {
                if isDropTargeted {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.accentColor, lineWidth: 2)
                }
            }
            .dropDestination(for: URL.self) { urls, _ in
                pickedURLs.append(contentsOf: urls.filter { !pickedURLs.contains($0) })
                return true
            } isTargeted: { isDropTargeted = $0 }

            HStack {
                Button("Add Files") { showFileImporter = true }
                    .fileImporter(isPresented: $showFileImporter,
                                  allowedContentTypes: [.item],
                                  allowsMultipleSelection: true) { result in
                        if case .success(let urls) = result {
                            pickedURLs.append(contentsOf: urls.filter { !pickedURLs.contains($0) })
                        }
                    }
                Button("Add Folder") { showFolderImporter = true }
                    .fileImporter(isPresented: $showFolderImporter,
                                  allowedContentTypes: [.folder]) { result in
                        if case .success(let url) = result, !pickedURLs.contains(url) {
                            pickedURLs.append(url)
                        }
                    }
            }
        }
    }

    // MARK: - Text

    private var textSection: some View {
        VStack(spacing: 12) {
            TextEditor(text: $text)
                .font(.body.monospaced())
                .frame(minHeight: 160, maxHeight: 280)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.secondary.opacity(0.3))
                }
            PasteButton(payloadType: String.self) { strings in
                if let pasted = strings.first {
                    Task { @MainActor in text = pasted }
                }
            }
        }
    }
}
