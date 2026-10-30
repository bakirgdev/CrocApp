import SwiftUI

/// The regular-width layout: a sidebar of Send, Receive, History (and Settings
/// on iPad) and a detail column (design/principles.md → Platform adaptation). Chosen
/// by `ContentView` from the horizontal size class, never by device.
///
/// The sidebar selection and each detail's pushed screens live in `AppRouter`,
/// because the app has one main window. This view only draws them: it never
/// selects a row or changes the detail on its own.
struct RegularLayout: View {
    @Environment(TransferController.self) private var controller
    @Environment(AppRouter.self) private var router

    /// The row of the transfer in flight and what it shows, if anything.
    private struct ActiveRow: Equatable {
        let item: AppRouter.SidebarItem
        let kind: SidebarRowState.Kind
    }

    private var activeRow: ActiveRow? {
        SidebarRowState(phase: controller.phase, progress: controller.progress).map {
            ActiveRow(item: AppRouter.SidebarItem(direction: controller.direction), kind: $0.kind)
        }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            // A new stack per row, so a screen pushed inside one row never
            // shows under another.
            DetailStack(root: router.selection.route)
                .id(router.selection)
        }
        // Announced once per phase, never per progress tick: only `activeRow`
        // is watched, and it carries no percent.
        .onChange(of: activeRow) { _, row in
            guard let row else { return }
            AccessibilityNotification.Announcement(
                SidebarRow.spoken(row.item, row.kind, percent: nil)
            ).post()
        }
    }

    private var sidebar: some View {
        List(
            selection: Binding<AppRouter.SidebarItem?>(
                get: { router.selection },
                set: { if let item = $0 { router.selection = item } })
        ) {
            ForEach(AppRouter.SidebarItem.rows) { item in
                SidebarRow(item: item, state: state(for: item))
                    .tag(item)
            }
        }
        .navigationTitle("CrocApp")
        #if os(macOS)
        // The Mac's default sidebar is 144 wide, which cuts "Receive" to an
        // ellipsis beside its Review badge. 240 is the sidebar the window
        // minimum is budgeted for (docs/knowledge/app-ui-architecture.md → Windows and keyboard focus).
        .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        #endif
    }

    private func state(for item: AppRouter.SidebarItem) -> SidebarRowState? {
        guard item == AppRouter.SidebarItem(direction: controller.direction) else { return nil }
        return SidebarRowState(phase: controller.phase, progress: controller.progress)
    }
}

extension AppRouter.Route {
    /// The screen a route pushes, in either layout's stack.
    @ViewBuilder var destination: some View {
        switch self {
        case .send: SendView()
        case .receive: ReceiveView()
        case .settings: SettingsScreen()
        case .advancedSettings: AdvancedSettingsView()
        case .howItWorks: HowItWorksView()
        case .history: HistoryView()
        }
    }

    /// The screen is a list or a form, which fills its container and does not
    /// cap itself. Send, Receive and How It Works cap their own column
    /// (`LayoutCap`), so the detail leaves them alone.
    fileprivate var isFullWidthList: Bool {
        switch self {
        case .history, .settings, .advancedSettings: true
        case .send, .receive, .howItWorks: false
        }
    }
}

/// One detail column: a `NavigationStack` per sidebar row, so How It Works and
/// Advanced settings push inside it and Back returns to the row's own screen.
private struct DetailStack: View {
    @Environment(AppRouter.self) private var router
    let root: AppRouter.Route

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.detailPath) {
            root.destination
                .detailScreen(root)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        NavigationLink(value: AppRouter.Route.howItWorks) {
                            Image(systemName: "lock.shield")
                        }
                        .accessibilityLabel("How croc keeps transfers private")
                    }
                }
                .navigationDestination(for: AppRouter.Route.self) { route in
                    route.destination.detailScreen(route)
                }
        }
    }
}

extension View {
    /// What every screen in the detail column gets: its content capped and
    /// centered (design/principles.md → Spacing and layout), and the live-request
    /// banner at its top (components.md → AcceptGate).
    fileprivate func detailScreen(_ route: AppRouter.Route) -> some View {
        modifier(DetailScreen(route: route))
    }
}

private struct DetailScreen: ViewModifier {
    let route: AppRouter.Route

    @Environment(TransferController.self) private var controller
    @Environment(AppRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var width: CGFloat = 0

    /// The gate is on screen when the row of the transfer's direction is
    /// selected and nothing is pushed over it. Anywhere else a request is easy
    /// to miss, because the sidebar can be hidden.
    private var showsBanner: Bool {
        controller.phase.needsAnswer
            && !(router.selection == AppRouter.SidebarItem(direction: controller.direction)
                && router.detailPath.isEmpty)
    }

    /// Margin that leaves a list's or form's content `LayoutCap.contentMaxWidth`
    /// wide. On iPad the list keeps its full-width background and the margin is
    /// the page. The Mac's list is a column of its own, and the toolbar's
    /// scroll edge above it is as wide as the column.
    private var listMargin: CGFloat {
        route.isFullWidthList ? max(0, (width - LayoutCap.contentMaxWidth) / 2) : 0
    }

    func body(content: Content) -> some View {
        content
            // Fills the detail, so the banner sits at its top instead of
            // travelling with a screen that centers its own content.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaPadding(.horizontal, listMargin)
            .safeAreaInset(edge: .top, spacing: 0) {
                if showsBanner {
                    RequestBanner()
                        .transition(Self.insert(reduceMotion: reduceMotion))
                }
            }
            .animation(reduceMotion ? nil : Motion.easeOut(Motion.durationBase), value: showsBanner)
            .onGeometryChange(for: CGFloat.self, of: { $0.size.width }, action: { width = $0 })
    }

    /// principles.md → Motion.
    private static func insert(reduceMotion: Bool) -> AnyTransition {
        guard !reduceMotion else { return .identity }
        return .asymmetric(
            insertion: .opacity.combined(with: .offset(y: -Spacing.space3))
                .animation(Motion.easeOut(Motion.durationBase)),
            removal: .opacity.animation(Motion.easeStandard(Motion.durationFast)))
    }
}

/// The pending-request banner of Home, for the detail column.
private struct RequestBanner: View {
    @Environment(TransferController.self) private var controller
    @Environment(AppRouter.self) private var router

    var body: some View {
        StatusBanner(
            kind: .info, title: title, detail: detail, actionTitle: "Review"
        ) {
            router.selection = AppRouter.SidebarItem(direction: controller.direction)
        }
        .padding(.horizontal, Spacing.space5)
        .padding(.vertical, Spacing.space3)
        .frame(maxWidth: LayoutCap.contentMaxWidth)
    }

    private var isConfirm: Bool {
        if case .confirmSend = controller.phase { return true }
        return false
    }

    private var title: String {
        isConfirm
            ? String(localized: "The other device is connected")
            : String(localized: "Files are waiting for your answer")
    }

    private var detail: String {
        isConfirm
            ? String(localized: "Send the selected items to the connected device?")
            : String(localized: "The other device is waiting for you to accept or decline.")
    }
}
