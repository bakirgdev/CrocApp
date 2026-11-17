import SwiftUI

/// The readable width of the content and of the actions on a wide screen.
private let columnWidth: CGFloat = 480

/// The layout of Send, Receive and every transfer state (issue #126): the
/// content scrolls, top-aligned in a readable column, above the screen's actions,
/// which sit in the bottom safe area, above the tab bar. The actions stay at one
/// place from state to state, and neither a long list nor large text pushes them
/// off the screen. One prominent button, at most two others.
struct ActionScreen<Content: View, Actions: View>: View {
    @ViewBuilder let content: Content
    @ViewBuilder let actions: Actions

    var body: some View {
        #if os(iOS)
        // iPhone Duo partially open like a book: the overlay arrangement moves
        // the column and its actions beside the fold instead of across it, and
        // puts them back when the fold flattens. A fold across a portrait
        // display is left alone, because the content scrolls past it.
        if #available(iOS 27.1, *) {
            ArrangementView {
                screen
            } secondary: {
                Color.clear
            }
            .arrangementViewStyle(.overlay.axes(.horizontal))
        } else {
            screen
        }
        #else
        screen
        #endif
    }

    private var screen: some View {
        // Padding inside the scroll view: outside it, the scroll view's clip
        // cuts off the Toggle switch, which draws past its frame.
        ScrollView {
            // fixedSize: without it a wrapping text is squeezed into an ellipsis.
            content
                .fixedSize(horizontal: false, vertical: true)
                .padding()
                .frame(maxWidth: columnWidth)
                .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            // Side by side when each label fits on one line, so the row keeps its
            // height; stacked when not (large text sizes, a third button).
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { actions }.lineLimit(1).environment(\.actionsInRow, true)
                VStack(spacing: 12) { actions }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .frame(maxWidth: columnWidth)
            .frame(maxWidth: .infinity)
            // The content scrolls under a bar, not between the buttons.
            .background(.bar)
        }
    }
}

extension EnvironmentValues {
    /// Set while the actions are laid out side by side.
    @Entry fileprivate var actionsInRow = false
}

/// Keeps a label from truncating in a row: `ViewThatFits` counts a truncated
/// text as fitting, so the label claims its full width and the row stacks instead.
private struct ActionLabel<Label: View>: View {
    @Environment(\.actionsInRow) private var inRow
    @ViewBuilder let label: Label

    var body: some View {
        label.fixedSize(horizontal: inRow, vertical: false).frame(maxWidth: .infinity)
    }
}

/// A button of the actions row: large and full width, so a row of them is of
/// equal widths and one height in every state.
func resultAction(
    _ title: LocalizedStringKey, prominent: Bool = true, action: @escaping () -> Void
) -> some View {
    resultAction(prominent: prominent, action: action) { Text(title) }
}

@ViewBuilder func resultAction(
    prominent: Bool = false, role: ButtonRole? = nil, action: @escaping () -> Void,
    @ViewBuilder label: () -> some View
) -> some View {
    let button = Button(role: role, action: action) {
        ActionLabel { label() }
    }
    if prominent {
        button.buttonStyle(.glassProminent).controlSize(.large)
    } else {
        button.buttonStyle(.glass).controlSize(.large)
    }
}

/// Cancel, Decline: a `.glass` button with a red label (a destructive role alone
/// draws a `.glass` label in the primary color).
func destructiveAction(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
    resultAction(role: .destructive, action: action) { Text(title).foregroundStyle(.red) }
}
