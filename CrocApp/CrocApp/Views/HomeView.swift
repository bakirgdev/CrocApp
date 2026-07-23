import SwiftUI

/// Two-verb home (prior-art pattern): giant Send / Receive, nothing else.
struct HomeView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                NavigationLink {
                    SendView()
                } label: {
                    Label("Send", systemImage: "arrow.up.circle.fill")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity, minHeight: 100)
                }
                .buttonStyle(.borderedProminent)

                NavigationLink {
                    ReceiveView()
                } label: {
                    Label("Receive", systemImage: "arrow.down.circle.fill")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity, minHeight: 100)
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .frame(maxWidth: 480)
            .navigationTitle("CrocApp")
        }
    }
}

#Preview { HomeView() }
