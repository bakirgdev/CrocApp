import OSLog
import SwiftUI
import UniformTypeIdentifiers

#if os(iOS)
import PhotosUI
#endif

/// Send flow (files, folders, text/clipboard, custom code).
struct SendView: View {
    @Environment(TransferController.self) private var controller
    @Environment(AppRouter.self) private var router
    @Environment(AppSettings.self) private var settings
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
    #if os(iOS)
    @State private var showPhotoPicker = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var isLoadingPhotos = false
    #endif
    /// Photos or videos the last pick could not bring in.
    @State private var photoFailures = 0
    @FocusState private var textFocused: Bool

    private static let log = Logger(subsystem: "com.bakirgdev.CrocApp", category: "send")

    // components.md → DropZone, "Staged list and text box": both keep the
    // DropZone's floor (so the Files tab does not change height as files
    // arrive) and grow to this cap, then scroll.
    private static let queueMaxHeight: CGFloat = 280

    // The system's own text inset inside a TextEditor, which the placeholder
    // copies. Not a token: it is whatever the platform draws.
    private static let placeholderInsetX: CGFloat = 5
    private static let placeholderInsetY: CGFloat = 8

    // motion.md → Choreography, rule 1: a choice that swaps a block.
    private var swapAnimation: Animation? {
        reduceMotion ? nil : Motion.easeOut(Motion.durationBase)
    }

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
            SendStaging.purgeOnce()
            consumePendingURLs()
            consumePendingText()
        }
        .onChange(of: router.pendingSendURLs) { _, _ in consumePendingURLs() }
        .onChange(of: router.pendingSendText) { _, _ in consumePendingText() }
        // Staged copies go with the screen, unless a transfer is reading them.
        .onDisappear {
            guard !controller.isActive else { return }
            pickedURLs.forEach(SendStaging.discard)
        }
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
                filesSection.transition(.opacity)
            } else {
                textSection.transition(.opacity)
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
                .transition(.opacity)
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
        .animation(swapAnimation, value: mode)
        .animation(swapAnimation, value: linkSelected)
        .modifier(SendPasteTarget { stage($0) })
    }

    private var customCodeTrimmed: String {
        customCode.trimmingCharacters(in: .whitespacesAndNewlines)
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
                Text(reason).font(.caption).foregroundStyle(Color.textSecondary)
                    .transition(.opacity)
            } else if linkSelected {
                VStack(alignment: .leading, spacing: Spacing.space3) {
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
                        .foregroundStyle(Color.textSecondary)
                    }
                }
                .transition(.opacity)
            } else {
                Text("Send encrypted files as a link instead of with a code.")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
                    .transition(.opacity)
            }
        }
    }

    private var serverHost: String {
        URL(string: settings.storedServer.trimmingCharacters(in: .whitespacesAndNewlines))
            .map(CodeHint.storedLink) ?? settings.storedServer
    }

    private var canStart: Bool {
        var isLoadingPhotos = false
        #if os(iOS)
        isLoadingPhotos = self.isLoadingPhotos
        #endif
        return SendReadiness(
            sendsAsLink: linkSelected,
            isFilesMode: mode == .files,
            hasFiles: !pickedURLs.isEmpty,
            hasText: !text.isEmpty,
            storedServerIsValid: AppSettings.storedServerError(settings.storedServer) == nil,
            customCode: customCodeTrimmed,
            isLoadingPhotos: isLoadingPhotos
        ).canStart
    }

    private func consumePendingURLs() {
        guard !router.pendingSendURLs.isEmpty else { return }
        mode = .files
        pickedURLs.append(contentsOf: router.pendingSendURLs.filter { !pickedURLs.contains($0) })
        router.pendingSendURLs = []
    }

    /// Takes what was dropped, pasted or picked. It only stages: starting is
    /// always the Send button. Files win over text, because a copied file
    /// often carries its name as text too.
    @discardableResult
    private func stage(_ payloads: [SendPayload]) -> Bool {
        let intake = SendIntake(payloads)
        let newFiles = intake.files.filter { !pickedURLs.contains($0) }
        if !newFiles.isEmpty {
            mode = .files
            pickedURLs.append(contentsOf: newFiles)
            return true
        }
        guard intake.files.isEmpty, let typed = intake.text(appendedTo: text) else {
            return false
        }
        mode = .text
        text = typed
        return true
    }

    /// Appends rather than replaces, so text the user already typed survives.
    private func consumePendingText() {
        guard let pending = router.pendingSendText else { return }
        mode = .text
        text = AppRouter.appending(pending, to: text)
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
                                SendStaging.discard(url)
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
                                .strokeBorder(Color.accentFill, lineWidth: DropZone.strokeWidth)
                        }
                    }
                }
            }
            // Files, and on iPad the images and text another app drags out.
            .dropDestination(for: SendPayload.self) { payloads, _ in
                stage(payloads)
            } isTargeted: {
                isDropTargeted = $0
            }

            // Side by side until the labels no longer fit (accessibility sizes).
            ViewThatFits(in: .horizontal) {
                HStack { importButtons }
                VStack { importButtons }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.item],
                allowsMultipleSelection: true
            ) { result in
                if case .success(let urls) = result {
                    pickedURLs.append(contentsOf: urls.filter { !pickedURLs.contains($0) })
                }
            }
            .fileImporter(
                isPresented: $showFolderImporter,
                allowedContentTypes: [.folder]
            ) { result in
                if case .success(let url) = result, !pickedURLs.contains(url) {
                    pickedURLs.append(url)
                }
            }
            #if os(iOS)
            .photosPicker(
                isPresented: $showPhotoPicker,
                selection: $photoItems,
                selectionBehavior: .ordered,
                matching: .any(of: [.images, .videos]),
                // The files as they are, not a re-encoded copy.
                preferredItemEncoding: .current
            )
            // A task tied to the pick: it is cancelled with the screen or when
            // the pick changes, and cancelling discards what it staged.
            .task(id: photoItems) { await addPhotos(photoItems) }
            #endif

            if photoFailures > 0 {
                StatusBanner(
                    kind: .error,
                    title: inflected(
                        AttributedString(
                            localized: "Couldn't add ^[\(photoFailures) item](inflect: true)",
                            comment:
                                "Title when photos or videos picked for Send could not be loaded.")),
                    detail: String(
                        localized:
                            "A photo in iCloud needs a connection to download. Check yours and try again.",
                        comment: "Says what to do after picked photos could not be loaded."))
            }
        }
    }

    @ViewBuilder private var importButtons: some View {
        Button("Add Files") { showFileImporter = true }
            .buttonVariant(.secondary)
        Button("Add Folder") { showFolderImporter = true }
            .buttonVariant(.secondary)
        #if os(iOS)
        Button {
            showPhotoPicker = true
        } label: {
            Label {
                Text("Add Photos")
            } icon: {
                if isLoadingPhotos { ProgressView() }
            }
        }
        .buttonVariant(.secondary)
        .disabled(isLoadingPhotos)
        #endif
    }

    #if os(iOS)
    /// Brings each picked photo or video in as a file with its own name. The
    /// picker runs out of process and hands over only what was picked, so the
    /// app asks for no photo library permission.
    private func addPhotos(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        isLoadingPhotos = true
        photoFailures = 0
        defer { isLoadingPhotos = false }
        guard
            let loaded = await SendLoading.load(
                items, using: { try await $0.loadTransferable(type: SendPayload.self) })
        else { return }
        photoFailures = loaded.failures
        stage(loaded.payloads)
        photoItems = []
    }
    #endif

    // MARK: - Text

    private var textSection: some View {
        VStack(spacing: Spacing.space4) {
            TextEditor(text: $text)
                .focused($textFocused)
                .accessibilityLabel("Text to send")
                .font(.body.monospaced())
                .frame(minHeight: DropZone.minHeight, maxHeight: Self.queueMaxHeight)
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        // TextEditor has no placeholder. The system draws its
                        // own text inset, so this one copies it.
                        Text("Type or paste the text to send.")
                            .font(.body.monospaced())
                            .foregroundStyle(Color.textSecondary)
                            .padding(.horizontal, Self.placeholderInsetX)
                            .padding(.vertical, Self.placeholderInsetY)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .strokeBorder(
                            textFocused ? Color.accentFill : Color.separatorToken,
                            lineWidth: BorderWidth.hairline)
                }
            PasteButton(payloadType: String.self) { strings in
                if let pasted = strings.first {
                    Task { @MainActor in text = pasted }
                }
            }
        }
    }
}

/// Lets the screen take a paste: ⌘V on a Mac, and on an iPad's hardware keyboard
/// from iOS 27, where SwiftUI gained the API. Before that an iPad pastes with the
/// buttons only.
///
/// Edit > Paste is enabled only while the view that accepts it has focus, so on a
/// Mac the screen takes the focus when it appears. The field and the editor on it
/// take it from the screen when clicked and paste into themselves.
private struct SendPasteTarget: ViewModifier {
    let action: ([SendPayload]) -> Void
    @FocusState private var hasFocus: Bool

    #if os(macOS)
    // Not `pasteDestination(for:)`: it imports every payload once to validate it
    // and again to deliver it, and each import of an image copies a file.
    // `onPasteCommand` is not available on iOS, which has only `pasteDestination`.
    private func paste(_ providers: [NSItemProvider]) {
        Task { action(await SendPayload.load(providers)) }
    }
    #endif

    @ViewBuilder func body(content: Content) -> some View {
        #if os(macOS)
        // The environment value reaches every child, so it is switched back on
        // for them: only this screen-level focus target hides its ring.
        content
            .focusEffectDisabled(false)
            .focusable()
            .focused($hasFocus)
            .focusEffectDisabled()
            .onPasteCommand(of: SendPayload.pasteTypes, perform: paste)
            .task { hasFocus = true }
        #else
        if #available(iOS 27.0, *) {
            content.pasteDestination(for: SendPayload.self, action: action)
        } else {
            content
        }
        #endif
    }
}
