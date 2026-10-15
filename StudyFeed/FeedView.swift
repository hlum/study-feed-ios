import SwiftUI

struct FeedView: View {
    @Environment(APIClient.self) private var api
    let store: FeedStore

    var body: some View {
        VStack(spacing: 0) {
            header
            if !store.cards.isEmpty { FilterBar(store: store) }
            if store.cards.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        if !store.stories.isEmpty {
                            StoriesRow(stories: store.stories).padding(.vertical, 12)
                            Divider().overlay(Theme.sep)
                        }
                        if store.visibleCards.isEmpty {
                            noMatches
                        }
                        ForEach(store.visibleCards) { card in
                            CardPage(card: card, onAnswered: { Task { await store.reloadStats() } })
                                .task { await store.cardAppeared(card) }
                            Divider().overlay(Theme.sep)
                        }
                        if store.isLoading { ProgressView().padding(24) }
                    }
                }
                .scrollIndicators(.hidden)
                .refreshable { await store.refresh() }
            }
        }
        .background(Theme.bg)
        .task { if store.cards.isEmpty { await store.refresh() } }
    }

    private var header: some View {
        HStack {
            Text("Study").font(.system(.title2, weight: .bold)).tracking(-0.4)
            Spacer()
            if let streak = store.stats?.streak {
                Label("\(streak) day streak", systemImage: "flame.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 48)
    }

    private var noMatches: some View {
        VStack(spacing: 10) {
            Text(store.isLoading ? "Looking for matches" : "Nothing here yet").font(.headline)
            Text("No loaded cards match this filter.").font(.subheadline).foregroundStyle(Theme.muted)
            Button("Show everything") { store.filter = FeedFilter() }
                .buttonStyle(.bordered).tint(Theme.accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            if store.isLoading {
                ProgressView()
            } else {
                Text(store.error ?? "No cards yet.")
                    .font(.body).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                Button("Try again") { Task { await store.refresh() } }
                    .buttonStyle(.borderedProminent).tint(Theme.accent).foregroundStyle(Theme.onAccent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}

/// One post in the feed: content, then its actions directly underneath.
struct CardPage: View {
    @Environment(APIClient.self) private var api
    let card: Card
    var onAnswered: () -> Void = {}

    @State private var quizCard: Card?
    @State private var askCard: Card?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content.padding(.horizontal, 20)
            ActionBar(card: card, onQuiz: { quizCard = card }, onAsk: { askCard = card })
                .padding(.horizontal, 16)
        }
        .padding(.vertical, 20)
        .environment(\.locale, card.locale)
        .task(id: card.id) {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await api.markSeen(card.id)
        }
        .sheet(item: $quizCard) { QuizSheet(card: $0, onAnswered: onAnswered).presentationDetents([.large]) }
        .sheet(item: $askCard) { AskSheet(card: $0).presentationDetents([.large]) }
    }

    @ViewBuilder private var content: some View {
        switch card.cardType {
        case .poster: PosterCard(card: card).frame(height: 480)
        case .post: PostCard(card: card)
        case .terminal: TerminalCard(card: card)
        }
    }
}

struct StoriesRow: View {
    let stories: [Story]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(stories) { story in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(story.topic.title).font(.caption.weight(.semibold))
                            .foregroundStyle(story.unseen ? Theme.accent : Theme.muted)
                        Text(story.preview).font(.footnote).lineLimit(2)
                            .foregroundStyle(story.unseen ? Theme.ink : Theme.muted)
                    }
                    .frame(width: 124, height: 64, alignment: .topLeading)
                    .padding(10)
                    .background(Theme.fill, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(story.unseen ? Theme.accent : .clear, lineWidth: 1.5))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 2)
        }
    }
}

struct ActionBar: View {
    @Environment(APIClient.self) private var api
    let card: Card
    let onQuiz: () -> Void
    let onAsk: () -> Void

    @State private var gotIt = false
    @State private var saved = false

    var body: some View {
        HStack(spacing: 4) {
            Button { gotIt.toggle(); Task { await api.react(card.id, kind: "got_it", on: gotIt) } } label: {
                Image(systemName: gotIt ? "heart.fill" : "heart").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Got it")
            Button(action: onAsk) {
                Image(systemName: "bubble.left").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Ask Claude")
            Button { saved.toggle(); Task { await api.react(card.id, kind: "save", on: saved) } } label: {
                Image(systemName: saved ? "bookmark.fill" : "bookmark").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Save")
            Spacer()
            Button(action: onQuiz) {
                Text(card.isRare ? "Quiz · 2× XP" : "Quiz")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16).frame(height: 40)
                    .overlay(Capsule().stroke(Theme.accent))
                    .foregroundStyle(Theme.accent)
            }
        }
        .font(.title3)
        .foregroundStyle(Theme.ink)
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: gotIt)
        .sensoryFeedback(.selection, trigger: saved)
    }
}
