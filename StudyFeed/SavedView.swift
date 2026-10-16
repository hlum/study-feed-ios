import SwiftUI

struct SavedView: View {
    let store: SavedStore

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Saved").font(.system(.title2, weight: .bold)).tracking(-0.4)
                Spacer()
                if !store.cards.isEmpty {
                    Text("\(store.cards.count)").font(.subheadline).foregroundStyle(Theme.muted)
                }
            }
            .padding(.horizontal, 20).frame(height: 48)

            if store.cards.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    if store.isLoading {
                        ProgressView()
                    } else if let error = store.error {
                        Text(error).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                        Button("Try again") { Task { await store.load() } }
                            .buttonStyle(.borderedProminent).tint(Theme.accent).foregroundStyle(Theme.onAccent)
                    } else {
                        Text("Nothing saved yet").font(.system(.title3, weight: .bold))
                        Text("Tap the bookmark under a post and it shows up here, ready to read later.")
                            .font(.body).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                    }
                    Spacer()
                    Spacer()
                }
                .padding(.horizontal, 32)
                .frame(maxWidth: .infinity)
                .refreshable { await store.load() }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.cards) { card in
                            CardPage(card: card)
                            Divider().overlay(Theme.sep)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .refreshable { await store.load() }
            }
        }
        .background(Theme.bg)
        .task { await store.load() }
    }
}
