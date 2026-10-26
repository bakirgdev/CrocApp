import SwiftUI
import UniformTypeIdentifiers

/// Send flow (files, folders, text/clipboard, custom code).
struct SendView: View {
    @Environment(TransferController.self) private var controller
    @Environment(AppRouter.self) private var router
    @Environment(AppSettings.self) private var settings
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    enum Mode: CaseIterable {
        case files
        case text

        var label: LocalizedStringKey {
            switch self {
            case .files: "Files"
            case .text: "Text"
            }
        }
    }

    @State private var mode: Mode = .files
    @State private var pickedURLs: [URL] = []
    @State private var text = ""
    @State private var customCode = ""
    @State private var showFileImporter = false
    @State private var showFolderImporter = false
    @State private var isDropTargeted = false
    @State private var sendAsLink = false
    @State private var linkLifetime = LinkLifetime.day
    @State private var linkDownloads = 1

    /// Cap on the staged-files list and the text editor; the floor is the
    /// DropZone's, so the Files tab does not change height as files arrive.
    private static let queueMaxHeight: CGFloat = 280
    /// The accent border a drag draws over the staged list (DropZone: 2pt).
    private let dropBorderWidth: CGFloat = 2

    /// How long a stored upload stays on the server.
    private enum LinkLifetime: Int, CaseIterable {
        case hour = 3_600
        case day = 86_400
        case week = 604_800

        var label: LocalizedStringKey {
            switch self {
            case .hour: "1 hour"
            case .day: "1 day"
            case .week: "7 days"
            }
        }
    }

    var body: some View {
        Group {
            // See ReceiveView: gate on direction too, or an active Receive
            // renders under the "Send" title.
            if controller.isActive, controller.direction == .send {
                TransferStatusView()
            } else {
                form
            }
        }
        .navigationTitle("Send")
        .onAppear {
            consumePendingURLs()
            consumePendingText()
        }
        .onChange(of: router.pendingSendURLs) { _, _ in consumePendingURLs() }
        .onChange(of: router.pendingSendText) { _, _ in consumePendingText() }
    }

    // At accessibility text sizes the form is taller than a phone screen, so it
    // scrolls there. Not ViewThatFits (as TransferStatusView uses): the keyboard
    // shrinks the space, which would swap the branch and drop the text field's
    // focus mid-typing.
    private var form: some View {
        Group {
            // Padding inside the scroll view: outside it, the scroll view's
            // clip cuts off the Toggle switch, which draws past its frame.
            if dynamicTypeSize.isAccessibilitySize {
                ScrollView { formContent.padding(Spacing.space5) }
            } else {
                formContent.padding(Spacing.space5)
            }
        }
        .frame(maxWidth: LayoutCap.contentMaxWidth)
    }

    private var formContent: some View {
        VStack(spacing: Spacing.space5) {
            Picker("What to Send", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { Text($0.label) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if mode == .files {
                filesSection
            } else {
                textSection
            }

            linkOptions

            if !linkSelected {
                CodeField(
                    placeholder: "Custom code (optional)",
                    text: $customCode,
                    isInvalid: !customCodeTrimmed.isEmpty
                        && customCodeTrimmed.count < EngineConstraints.minCodeLength,
                    invalidMessage: CodeField.tooShortMessage
                ) { pasted in
                    customCode = pasted
                }
            }

            Button {
                if linkSelected {
                    controller.start(
                        .storedSend(
                            urls: pickedURLs, downloads: linkDownloads,
                            lifetimeSeconds: linkLifetime.rawValue))
                } else if mode == .files {
                    controller.start(.sendFiles(urls: pickedURLs, code: customCodeTrimmed))
                } else {
                    controller.start(.sendText(text: text, code: customCodeTrimmed))
                }
            } label: {
                Label(
                    linkSelected ? "Send as Link" : "Send",
                    systemImage: linkSelected ? "link.circle.fill" : "arrow.up.circle.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonVariant(.prominent)
            .controlSize(.large)
            .disabled(!canStart)
        }
    }

    private var customCodeTrimmed: String {
        customCode.trimmingCharacters(in: .whitespaces)
    }

    /// Why "Send as link" cannot be used for what is staged, or nil.
    private var linkUnavailableReason: String? {
        if mode == .text {
            return String(localized: "Text can't be sent as a link. Switch to Files.")
        }
        if pickedURLs.contains(where: Self.isFolder) {
            return String(
                localized:
                    "Folders can't be sent as a link. Remove the folders, or send them with a code."
            )
        }
        return nil
    }

    /// The link server's problem and where to fix it, or nil when it is fine.
    private var storedServerProblem: String? {
        AppSettings.storedServerError(settings.storedServer).map {
            String(
                localized: "\($0) Change it in Settings.",
                comment: "The placeholder is a sentence saying what is wrong with the link server.")
        }
    }

    /// What the banner and caption below the toggle say, read with the toggle.
    private var linkToggleHint: String {
        if let reason = linkUnavailableReason { return reason }
        if linkSelected, let problem = storedServerProblem { return problem }
        return ""
    }

    private var linkSelected: Bool { sendAsLink && linkUnavailableReason == nil }

    private static func isFolder(_ url: URL) -> Bool {
        url.hasDirectoryPath
            || (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    @ViewBuilder private var linkOptions: some View {
        VStack(alignment: .leading, spacing: Spacing.space3) {
            Toggle("Send as Link", isOn: Binding(get: { linkSelected }, set: { sendAsLink = $0 }))
                .disabled(linkUnavailableReason != nil)
                .accessibilityHint(linkToggleHint)
            if let reason = linkUnavailableReason {
                Text(reason).font(.caption).foregroundStyle(.secondary)
            } else if linkSelected {
                Picker("Link Lasts", selection: $linkLifetime) {
                    ForEach(LinkLifetime.allCases, id: \.self) { Text($0.label) }
                }
                Stepper(value: $linkDownloads, in: 1...100) {
                    Text("Downloads allowed: \(linkDownloads)")
                }
                if let problem = storedServerProblem {
                    StatusBanner(kind: .error, title: problem)
                } else {
                    Text(
                        "Files are encrypted on this device before they reach \(serverHost). Anyone with the link can receive them until it expires or runs out."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            } else {
                Text("Send encrypted files as a link instead of with a code.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var serverHost: String {
        URL(string: settings.storedServer.trimmingCharacters(in: .whitespacesAndNewlines))
            .map(CodeHint.storedLink) ?? settings.storedServer
    }

    private var canStart: Bool {
        if linkSelected {
            return !pickedURLs.isEmpty
                && AppSettings.storedServerError(settings.storedServer) == nil
        }
        let codeOK =
            customCode.isEmpty || customCodeTrimmed.count >= EngineConstraints.minCodeLength
        let payloadOK = mode == .files ? !pickedURLs.isEmpty : !text.isEmpty
        return codeOK && payloadOK
    }

    private func consumePendingURLs() {
        guard !router.pendingSendURLs.isEmpty else { return }
        mode = .files
        pickedURLs.append(contentsOf: router.pendingSendURLs.filter { !pickedURLs.contains($0) })
        router.pendingSendURLs = []
    }

    /// Appends rather than replaces, so text the user already typed survives.
    private func consumePendingText() {
        guard let pending = router.pendingSendText else { return }
        mode = .text
        text = text.isEmpty ? pending : text + "\n" + pending
        router.pendingSendText = nil
    }

    // MARK: - Files

    private var filesSection: some View {
        VStack(spacing: Spacing.space4) {
            Group {
                if pickedURLs.isEmpty {
                    DropZone(
                        title: "Drop files or folders here",
                        hint: "or add them with the buttons below",
                        isTargeted: isDropTargeted)
                } else {
                    List {
                        ForEach(Array(pickedURLs.enumerated()), id: \.element) { index, url in
                            FileRow(
                                url: url,
                                isFirst: index == 0,
                                isLast: index == pickedURLs.count - 1
                            ) {
                                pickedURLs.removeAll { $0 == url }
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                    }
                    // Matches IncomingRequestView's own fix for the same
                    // problem: without this the List paints the system
                    // grouped background behind FileRow's own card fill.
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: DropZone.minHeight, maxHeight: Self.queueMaxHeight)
                    .overlay {
                        // The empty DropZone draws its own drag-over state;
                        // a list in the way gets the same accent border.
                        if isDropTargeted {
                            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                                .strokeBorder(Color.accentFill, lineWidth: dropBorderWidth)
                        }
                    }
                }
            }
            .dropDestination(for: URL.self) { urls, _ in
                let files = urls.filter(\.isFileURL)
                guard !files.isEmpty else { return false }
                let newFiles = files.filter { !pickedURLs.contains($0) }
                pickedURLs.append(contentsOf: newFiles)
                return !newFiles.isEmpty
            } isTargeted: {
                isDropTargeted = $0
            }

            // Side by side until the labels no longer fit (accessibility sizes).
            ViewThatFits(in: .horizontal) {
                HStack { importButtons }
                VStack { importButtons }
            }
        }
    }

    @ViewBuilder private var importButtons: some View {
        Button("Add Files") { showFileImporter = true }
            .buttonVariant(.secondary)
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.item],
                allowsMultipleSelection: true
            ) { result in
                if case .success(let urls) = result {
                    pickedURLs.append(contentsOf: urls.filter { !pickedURLs.contains($0) })
                }
            }
        Button("Add Folder") { showFolderImporter = true }
            .buttonVariant(.secondary)
            .fileImporter(
                isPresented: $showFolderImporter,
                allowedContentTypes: [.folder]
            ) { result in
                if case .success(let url) = result, !pickedURLs.contains(url) {
                    pickedURLs.append(url)
                }
            }
    }

    // MARK: - Text

    private var textSection: some View {
        VStack(spacing: Spacing.space4) {
            TextEditor(text: $text)
                .accessibilityLabel("Text to send")
                .font(.body.monospaced())
                .frame(minHeight: DropZone.minHeight, maxHeight: Self.queueMaxHeight)
                .overlay {
                    // Not a named component; nearest token to the prior 8pt radius.
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .strokeBorder(Color.separatorToken, lineWidth: BorderWidth.hairline)
                }
            PasteButton(payloadType: String.self) { strings in
                if let pasted = strings.first {
                    Task { @MainActor in text = pasted }
                }
            }
        }
    }
}
