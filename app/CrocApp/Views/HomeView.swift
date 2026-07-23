import SwiftUI

/// Two-verb home (prior-art pattern): giant Send / Receive, nothing else.
struct HomeView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            VStack(spacing: 20) {
                NavigationLink(value: AppRouter.Route.send) {
                    Label("Send", systemImage: "arrow.up.circle.fill")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity, minHeight: 100)
                }
                .buttonStyle(.borderedProminent)

                NavigationLink(value: AppRouter.Route.receive) {
                    Label("Receive", systemImage: "arrow.down.circle.fill")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity, minHeight: 100)
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .frame(maxWidth: 480)
            .navigationTitle("CrocApp")
            .navigationDestination(for: AppRouter.Route.self) { route in
                switch route {
                case .send: SendView()
                case .receive: ReceiveView()
                }
            }
        }
    }
}

#Preview { HomeView().environment(AppRouter.shared) }
