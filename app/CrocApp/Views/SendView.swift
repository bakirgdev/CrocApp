import CrocKit
import SwiftUI
import UniformTypeIdentifiers

#if os(iOS)
import PhotosUI
#endif

struct SendView: View {
    @Bindable var draft: SendDraft
    @Environment(TransferController.self) private var controller
    @Environment(AppSettings.self) private var settings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Sizes of `draft.pickedURLs`, read off the main actor; a row has none until then.
    @State private var pickedSizes: [URL: Int64] = [:]
    /// Whether `draft.pickedURLs` holds a folder, read once per change: the body
    /// reads it several times per progress tick, and each read is a stat.
    @State private var hasFolder = false
    @State private var showFileImporter = false
    @State private var showFolderImporter = false
    @State private var isDropTargeted = false
    #if os(iOS)
    @State private var showPhotoPicker = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var isLoadingPhotos = false
    #endif
    @State private var photoFailures = 0
    @FocusState private var textFocused: Bool

    // The text box keeps the DropZone's floor and grows to this cap, then scrolls.
    private static let textMaxHeight: CGFloat = 280

    // The system's own text inset inside a TextEditor, which the placeholder
    // copies. Not a token: it is whatever the platform draws.
    private static let placeholderInsetX: CGFloat = 5
    private static let placeholderInsetY: CGFloat = 8

    private var swapAnimation: Animation? {
        reduceMotion ? nil : .default
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
        .onAppear { SendStaging.purgeOnce() }
    }

    private var form: some View {
        ActionScreen {
            formContent
        } actions: {
            resultAction(prominent: true, action: start) {
                Label(
                    linkSelected ? "Send as Link" : "Send",
                    systemImage: linkSelected ? "link.circle.fill" : "arrow.up.circle.fill"
                )
            }
            .disabled(!canStart)
        }
    }

    private func start() {
        let request: TransferRequest =
            if linkSelected {
                .storedSend(
                    urls: draft.pickedURLs, downloads: draft.linkDownloads,
                    lifetimeSeconds: draft.linkLifetime.rawValue)
            } else if draft.mode == .files {
                .sendFiles(urls: draft.pickedURLs, code: customCodeTrimmed)
            } else {
                .sendText(text: draft.text, code: customCodeTrimmed)
            }
        if controller.start(request) { draft.started = request }
    }

    private var formContent: some View {
        VStack(spacing: 16) {
            Picker("What to Send", selection: $draft.mode) {
                ForEach(SendDraft.Mode.allCases, id: \.self) { Text($0.label) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if draft.mode == .files {
                filesSection.transition(.opacity)
            } else {
                textSection.transition(.opacity)
            }

            linkOptions

            if !linkSelected {
                VStack(alignment: .leading) {
                    CodeField(
                        placeholder: "Custom code (optional)",
                        text: $draft.customCode,
                        isInvalid: !customCodeTrimmed.isEmpty
                            && !EngineConstraints.isValidCode(customCodeTrimmed),
                        invalidMessage: CodeField.tooShortMessage
                    ) { pasted in
                        draft.customCode = pasted
                    }
                    SavedCodePicker(selection: draft.customCode) { draft.customCode = $0 }
                }
                .transition(.opacity)
            }
        }
        .animation(swapAnimation, value: draft.mode)
        .animation(swapAnimation, value: linkSelected)
        .modifier(SendPasteTarget { draft.stage($0) })
    }

    private var customCodeTrimmed: String {
        draft.customCode.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Why "Send as link" cannot be used for what is staged, or nil.
    private var linkUnavailableReason: String? {
        if draft.mode == .text {
            return String(localized: "Text can't be sent as a link. Switch to Files.")
        }
        if hasFolder {
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

    private var linkSelected: Bool { draft.sendAsLink && linkUnavailableReason == nil }

    private static func isFolder(_ url: URL) -> Bool {
        url.hasDirectoryPath
            || (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    @ViewBuilder private var linkOptions: some View {
        VStack(alignment: .leading) {
            Toggle(
                "Send as Link", isOn: Binding(get: { linkSelected }, set: { draft.sendAsLink = $0 })
            )
            .disabled(linkUnavailableReason != nil)
            .accessibilityHint(linkToggleHint)
            if let reason = linkUnavailableReason {
                Text(reason).font(.caption).foregroundStyle(.secondary)
                    .transition(.opacity)
            } else if linkSelected {
                VStack(alignment: .leading) {
                    Picker("Link Lasts", selection: $draft.linkLifetime) {
                        ForEach(SendDraft.LinkLifetime.allCases, id: \.self) { Text($0.label) }
                    }
                    Stepper(value: $draft.linkDownloads, in: 1...EngineLimits.storeMaxDownloads) {
                        Text("Downloads allowed: \(draft.linkDownloads)")
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
                }
                .transition(.opacity)
            } else {
                Text("Send encrypted files as a link instead of with a code.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
            isFilesMode: draft.mode == .files,
            hasFiles: !draft.pickedURLs.isEmpty,
            hasText: !draft.text.isEmpty,
            storedServerIsValid: AppSettings.storedServerError(settings.storedServer) == nil,
            customCode: customCodeTrimmed,
            isLoadingPhotos: isLoadingPhotos
        ).canStart && !controller.isActive
    }

    // MARK: - Files

    private var filesSection: some View {
        VStack(spacing: 12) {
            Group {
                if draft.pickedURLs.isEmpty {
                    DropZone(
                        title: "Drop files or folders here",
                        hint: "or add them with the button below",
                        isTargeted: isDropTargeted)
                } else {
                    // Plain rows: the page scrolls, so every file is reachable
                    // at any text size and no button covers a row.
                    GroupBox {
                        VStack(spacing: 0) {
                            ForEach(Array(draft.pickedURLs.enumerated()), id: \.element) {
                                index, url in
                                FileRow(url: url, size: pickedSizes[url]) {
                                    draft.pickedURLs.removeAll { $0 == url }
                                    SendStaging.discard(url)
                                }
                                if index < draft.pickedURLs.count - 1 { Divider() }
                            }
                        }
                    }
                    .overlay {
                        // The empty DropZone draws its own drag-over state;
                        // a list in the way gets the same accent border.
                        if isDropTargeted {
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(Color.accentColor, lineWidth: DropZone.strokeWidth)
                        }
                    }
                }
            }
            .task(id: draft.pickedURLs) {
                hasFolder = draft.pickedURLs.contains(where: Self.isFolder)
                let missing = draft.pickedURLs.filter { pickedSizes[$0] == nil }
                pickedSizes.merge(await FileSize.bytes(ofEach: missing)) { $1 }
            }
            // Files, and on iPad the images and text another app drags out.
            .dropDestination(for: SendPayload.self) { payloads, _ in
                draft.stage(payloads)
            } isTargeted: {
                isDropTargeted = $0
            }

            addMenu
                .fileImporter(
                    isPresented: $showFileImporter,
                    allowedContentTypes: [.item],
                    allowsMultipleSelection: true
                ) { result in
                    if case .success(let urls) = result {
                        draft.add(urls)
                    }
                }
                .fileImporter(
                    isPresented: $showFolderImporter,
                    allowedContentTypes: [.folder]
                ) { result in
                    if case .success(let url) = result { draft.add([url]) }
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

    // One menu instead of three buttons that stack at three widths on a small
    // phone. The items keep the old buttons' accessibility labels.
    private var addMenu: some View {
        Menu {
            Button {
                showFileImporter = true
            } label: {
                Label("Files", systemImage: "doc")
            }
            .accessibilityLabel("Add Files")
            Button {
                showFolderImporter = true
            } label: {
                Label("Folder", systemImage: "folder")
            }
            .accessibilityLabel("Add Folder")
            #if os(iOS)
            Button {
                showPhotoPicker = true
            } label: {
                Label("Photos", systemImage: "photo.on.rectangle")
            }
            .accessibilityLabel("Add Photos")
            .disabled(isLoadingPhotos)
            #endif
        } label: {
            Label {
                Text("Add")
            } icon: {
                #if os(iOS)
                if isLoadingPhotos { ProgressView() } else { Image(systemName: "plus") }
                #else
                Image(systemName: "plus")
                #endif
            }
        }
        .buttonStyle(.glass)
        .controlSize(.large)
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
        draft.stage(loaded.payloads)
        photoItems = []
    }
    #endif

    // MARK: - Text

    private var textSection: some View {
        VStack(spacing: 12) {
            TextEditor(text: $draft.text)
                .focused($textFocused)
                .accessibilityLabel("Text to send")
                .font(.body.monospaced())
                .frame(minHeight: DropZone.minHeight, maxHeight: Self.textMaxHeight)
                .overlay(alignment: .topLeading) {
                    if draft.text.isEmpty {
                        // TextEditor has no placeholder. The system draws its
                        // own text inset, so this one copies it.
                        Text("Type or paste the text to send.")
                            .font(.body.monospaced())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, Self.placeholderInsetX)
                            .padding(.vertical, Self.placeholderInsetY)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(textFocused ? Color.accentColor : Color.secondary)
                }
            PasteButton(payloadType: String.self) { strings in
                if let pasted = strings.first {
                    Task { @MainActor in draft.text = pasted }
                }
            }
            // The code field has a second PasteButton, and the system names both "Paste".
            .accessibilityLabel("Paste text")
            .accessibilityInputLabels(["Paste text"])
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

extension SendDraft.Mode {
    fileprivate var label: LocalizedStringKey {
        switch self {
        case .files: "Files"
        case .text: "Text"
        }
    }
}

extension SendDraft.LinkLifetime {
    fileprivate var label: LocalizedStringKey {
        switch self {
        case .hour: "1 hour"
        case .day: "1 day"
        case .week: "7 days"
        }
    }
}
