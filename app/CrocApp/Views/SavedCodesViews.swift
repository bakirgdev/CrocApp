import SwiftUI

/// One-tap choice of a saved code, under the code field of Send and Receive.
/// Draws nothing until the user has saved a code.
struct SavedCodePicker: View {
    @Environment(SavedCodes.self) private var savedCodes
    let selection: String
    let onPick: (String) -> Void

    var body: some View {
        if !savedCodes.codes.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.space2) {
                    ForEach(savedCodes.codes) { saved in
                        Button {
                            onPick(saved.code)
                        } label: {
                            Label(saved.name, systemImage: "key")
                        }
                        .buttonVariant(.secondary)
                        .controlSize(.small)
                        .accessibilityValue(
                            selection.trimmingCharacters(in: .whitespacesAndNewlines) == saved.code
                                ? "Selected" : ""
                        )
                        .accessibilityHint("Fills in the saved code")
                    }
                }
            }
        }
    }
}

/// Settings section that lists, adds, renames and deletes saved codes.
/// A code is never shown in the list, only in the editor.
struct SavedCodesSection: View {
    @Environment(SavedCodes.self) private var savedCodes
    @State private var editing: SavedCodeEditor.Target?

    var body: some View {
        Section {
            ForEach(savedCodes.codes) { saved in
                Button {
                    editing = .existing(saved)
                } label: {
                    Label(saved.name, systemImage: "key")
                }
                .buttonVariant(.plain)
                .swipeActions {
                    Button("Delete", role: .destructive) { savedCodes.remove(id: saved.id) }
                }
                .contextMenu {
                    Button("Delete", role: .destructive) { savedCodes.remove(id: saved.id) }
                }
            }
            Button {
                editing = .new
            } label: {
                Label("Add Saved Code", systemImage: "plus")
            }
            .buttonVariant(.plain)
            .disabled(savedCodes.loadFailed)
            if savedCodes.loadFailed {
                StatusBanner(
                    kind: .error, title: String(localized: "Couldn't read saved codes"),
                    detail: String(
                        localized:
                            "The Keychain is not available yet, for example before you first unlock this device. Nothing is changed until it can be read."
                    ),
                    actionTitle: "Try Again", action: { savedCodes.reload() })
            }
            if savedCodes.saveFailed {
                StatusBanner(
                    kind: .error, title: AppSettings.secretNotSavedTitle,
                    detail: String(
                        localized:
                            "Change it again before you quit CrocApp, or the next launch shows what was saved before."
                    ))
            }
        } header: {
            Text("Saved codes")
        } footer: {
            Text(SavedCodeEditor.reuseWarning)
                .foregroundStyle(Color.textSecondary)
        }
        .sheet(item: $editing) { SavedCodeEditor(target: $0) }
    }
}

/// Adds or edits one saved code. Carries the warning that a reused code is
/// no longer single-use (docs/THREAT-MODEL.md, "Saved codes").
struct SavedCodeEditor: View {
    enum Target: Identifiable {
        case new
        case existing(SavedCode)

        private static let newID = UUID()

        var id: UUID {
            switch self {
            case .new: Self.newID
            case .existing(let saved): saved.id
            }
        }
    }

    /// Shown wherever a code is saved.
    static var reuseWarning: String {
        String(
            localized:
                "A saved code is kept in this device's Keychain and never synced. Using it again means it is no longer single-use: anyone who learns it and connects first can receive your next transfer."
        )
    }

    @Environment(SavedCodes.self) private var savedCodes
    @Environment(\.dismiss) private var dismiss
    let target: Target
    @State private var name = ""
    @State private var code = ""
    @State private var loaded = false

    private var existing: SavedCode? {
        if case .existing(let saved) = target { saved } else { nil }
    }

    private var trimmedCode: String { code.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name, prompt: Text("Who it is for"))
                    TextField("Code phrase", text: $code)
                        .font(.body.monospaced())
                        .autocorrectionDisabled()
                        #if os(iOS)
                    .textInputAutocapitalization(.never)
                        #endif
                } footer: {
                    if !trimmedCode.isEmpty, trimmedCode.count < EngineConstraints.minCodeLength {
                        Text(CodeField.tooShortMessage).foregroundStyle(Color.textSecondary)
                    }
                }
                Section {
                    StatusBanner(
                        kind: .warning, title: String(localized: "A saved code is not single-use"),
                        detail: String(
                            localized:
                                "Anyone who learns it and connects first can receive your next transfer."
                        ))
                }
                if let existing {
                    Section {
                        Button("Delete Saved Code", role: .destructive) {
                            savedCodes.remove(id: existing.id)
                            dismiss()
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(existing == nil ? "Add Saved Code" : "Edit Saved Code")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savedCodes.save(
                            SavedCode(id: existing?.id ?? UUID(), name: name, code: code))
                        dismiss()
                    }
                    .disabled(!SavedCode.isValid(name: name, code: code))
                }
            }
        }
        .onAppear {
            guard !loaded, let existing else { return }
            loaded = true
            name = existing.name
            code = existing.code
        }
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 360)
        #endif
    }
}
