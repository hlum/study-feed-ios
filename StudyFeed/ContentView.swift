import SwiftUI

struct ContentView: View {
    @State private var api: APIClient
    @State private var store: FeedStore

    init() {
        let api = APIClient()
        _api = State(initialValue: api)
        _store = State(initialValue: FeedStore(api: api))
    }

    var body: some View {
        TabView {
            Tab("Feed", systemImage: "rectangle.portrait.on.rectangle.portrait") {
                FeedView(store: store)
            }
            Tab("Review", systemImage: "rectangle.stack") {
                Text("Review").foregroundStyle(Theme.muted)
            }
            Tab("You", systemImage: "person") {
                YouView(store: store)
            }
        }
        .environment(api)
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
    }
}

struct YouView: View {
    @Environment(APIClient.self) private var api
    let store: FeedStore
    @State private var status: String?

    var body: some View {
        @Bindable var api = api
        NavigationStack {
            Form {
                Section {
                    TextField("http://100.x.y.z:8001", text: $api.baseURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Test connection") {
                        Task {
                            do {
                                let s = try await api.stats()
                                status = "Connected. Level \(s.level), \(s.streak) day streak."
                                await store.refresh()
                            } catch {
                                status = error.localizedDescription
                            }
                        }
                    }
                    if let status { Text(status).font(.footnote).foregroundStyle(Theme.muted) }
                } header: {
                    Text("Server")
                } footer: {
                    Text("Your phone must be on the same Tailscale network as the server.")
                }
            }
            .navigationTitle("You")
        }
    }
}

#Preview {
    ContentView()
}
