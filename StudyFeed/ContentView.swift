import SwiftUI

enum AppTab { case feed, review, saved, you }

struct ContentView: View {
    @State private var api: APIClient
    @State private var store: FeedStore
    @State private var review: ReviewStore
    @State private var saved: SavedStore
    @State private var tab = AppTab.feed

    init() {
        let api = APIClient()
        _api = State(initialValue: api)
        _store = State(initialValue: FeedStore(api: api))
        _review = State(initialValue: ReviewStore(api: api))
        _saved = State(initialValue: SavedStore(api: api))
    }

    var body: some View {
        TabView(selection: $tab) {
            Tab("Feed", systemImage: "rectangle.portrait.on.rectangle.portrait", value: AppTab.feed) {
                FeedView(store: store)
            }
            Tab("Review", systemImage: "rectangle.stack", value: AppTab.review) {
                ReviewView(store: review)
            }
            .badge(review.dueCount)
            Tab("Saved", systemImage: "bookmark", value: AppTab.saved) {
                SavedView(store: saved)
            }
            Tab("You", systemImage: "person", value: AppTab.you) {
                YouView(store: store, goToFeed: { tab = .feed })
            }
        }
        .environment(api)
        .environment(saved)
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
        .task {
            await review.load()
            await saved.load()
        }
    }
}

#Preview {
    ContentView()
}
