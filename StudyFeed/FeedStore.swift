import Foundation
import Observation

/// Which cards the feed shows. Empty sets mean "all". Within topics, or within sites,
/// a card needs to match any one chosen; across groups it must match every group.
struct FeedFilter: Equatable {
    var kind: String?          // "news" | "lesson"
    var topics: Set<Topic> = []
    var siteKeys: Set<String> = []
    var japanese = false

    var isActive: Bool { kind != nil || !topics.isEmpty || !siteKeys.isEmpty || japanese }

    func matches(_ card: Card) -> Bool {
        if let kind, card.resolvedKind != kind { return false }
        if !topics.isEmpty, !topics.contains(card.topic) { return false }
        if !siteKeys.isEmpty, !(card.siteKey.map(siteKeys.contains) ?? false) { return false }
        if japanese, card.lang != "ja" { return false }
        return true
    }
}

@MainActor @Observable
final class FeedStore {
    var cards: [Card] = []
    var stories: [Story] = []
    var stats: Stats?
    var error: String?
    var isLoading = false
    var filter = FeedFilter() { didSet { if oldValue != filter { Task { await loadMoreIfSparse() } } } }

    @ObservationIgnored private let api: APIClient
    @ObservationIgnored private var cursor: Int?
    @ObservationIgnored private var reachedEnd = false

    init(api: APIClient) { self.api = api }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let page = try await api.feed(cursor: nil)
            cards = page.cards
            cursor = page.nextCursor
            reachedEnd = page.cards.isEmpty
            error = nil
            stories = (try? await api.stories()) ?? []
            stats = try? await api.stats()
            if let stats { Reminder.update(with: stats) }
        } catch {
            self.error = error.localizedDescription
        }
    }

    var visibleCards: [Card] { filter.isActive ? cards.filter(filter.matches) : cards }

    /// Topics present in the loaded cards, most common first.
    var topics: [Topic] {
        Dictionary(grouping: cards, by: \.topic).sorted { $0.value.count > $1.value.count }.map(\.key)
    }

    /// Sites for the chip row: from the loaded news cards that pass the other filters, so choosing
    /// 日本語 or a topic narrows the row to the sites that matter. Chosen sites always stay listed.
    var sites: [(key: String, name: String)] {
        var others = filter
        others.siteKeys = []
        let pool = others.isActive ? cards.filter(others.matches) : cards
        func names(_ cards: [Card]) -> [(key: String, name: String)] {
            let news = cards.compactMap { c in c.siteKey.map { ($0, c.siteName ?? $0) } }
            return Dictionary(grouping: news, by: \.0).sorted { $0.value.count > $1.value.count }
                .compactMap { $0.value.first.map { (key: $0.0, name: $0.1) } }
        }
        var result = names(pool)
        for chosen in names(cards) where filter.siteKeys.contains(chosen.key) && !result.contains(where: { $0.key == chosen.key }) {
            result.append(chosen)
        }
        return result
    }

    /// The next part of this card's series, if it is among the cards being shown.
    func nextPart(of card: Card) -> Card? {
        guard let series = card.seriesId, let part = card.part else { return nil }
        return visibleCards.first { $0.seriesId == series && $0.part == part + 1 }
    }

    var hasJapanese: Bool { cards.contains { $0.lang == "ja" } }

    /// A narrow filter may match few of the loaded cards; keep paging until there is something to read.
    func loadMoreIfSparse() async {
        var attempts = 0
        while filter.isActive, visibleCards.count < 6, !reachedEnd, attempts < 6 {
            attempts += 1
            await loadNextPage()
        }
    }

    func reloadStats() async {
        stats = (try? await api.stats()) ?? stats
        if let stats { Reminder.update(with: stats) }
    }

    /// Call as a card appears; loads the next page when the reader is near the end.
    func cardAppeared(_ card: Card) async {
        let visible = visibleCards
        guard let index = visible.firstIndex(of: card), index >= visible.count - 3 else { return }
        await loadNextPage()
    }

    private func loadNextPage() async {
        guard !reachedEnd, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let page = try await api.feed(cursor: cursor)
            let known = Set(cards.map(\.id))
            let fresh = page.cards.filter { !known.contains($0.id) }
            cards += fresh
            cursor = page.nextCursor
            reachedEnd = fresh.isEmpty
        } catch {
            self.error = error.localizedDescription
        }
    }
}
