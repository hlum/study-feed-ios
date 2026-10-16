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

    /// Sites the reader chose to hide: key -> display name. Kept on this phone.
    var hiddenSites: [String: String] = UserDefaults.standard.dictionary(forKey: "hiddenSites") as? [String: String] ?? [:] {
        didSet { UserDefaults.standard.set(hiddenSites, forKey: "hiddenSites") }
    }

    @ObservationIgnored private let api: APIClient
    @ObservationIgnored private var cursor: Int?
    @ObservationIgnored private var reachedEnd = false

    init(api: APIClient) { self.api = api }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let page = try await api.feed(cursor: nil, limit: 50)   // enough cards that every site has a chip
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

    private func isHidden(_ card: Card) -> Bool { card.siteKey.map { hiddenSites[$0] != nil } ?? false }

    /// Loaded cards minus the sites you hid.
    private var shownCards: [Card] { hiddenSites.isEmpty ? cards : cards.filter { !isHidden($0) } }

    var visibleCards: [Card] { filter.isActive ? shownCards.filter(filter.matches) : shownCards }

    func hide(_ card: Card) {
        guard let key = card.siteKey, let name = card.siteName else { return }
        hiddenSites[key] = name
        filter.siteKeys.remove(key)
    }

    func unhide(_ key: String) { hiddenSites[key] = nil }

    /// Topics present in the loaded cards. Alphabetical, so the menu never reshuffles.
    var topics: [Topic] {
        Set(shownCards.map(\.topic)).sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    /// Sites for the chip row, alphabetical so chips never jump when you pick one or more cards load.
    /// Choosing 日本語 or a topic narrows the row to sites that have matching cards; chosen sites stay listed.
    var sites: [(key: String, name: String)] {
        var others = filter
        others.siteKeys = []
        let pool = others.isActive ? shownCards.filter(others.matches) : shownCards
        var available = Set(pool.compactMap(\.siteKey)).union(filter.siteKeys)
        available.formIntersection(shownCards.compactMap(\.siteKey))
        var names: [String: String] = [:]
        for card in shownCards { if let key = card.siteKey, names[key] == nil { names[key] = card.siteName ?? key } }
        return available.compactMap { key in names[key].map { (key: key, name: $0) } }
            .sorted {
                let order = $0.name.localizedCaseInsensitiveCompare($1.name)
                return order == .orderedSame ? $0.key < $1.key : order == .orderedAscending
            }
    }

    /// The next part of this card's series, if it is among the cards being shown.
    func nextPart(of card: Card) -> Card? {
        guard let series = card.seriesId, let part = card.part else { return nil }
        return visibleCards.first { $0.seriesId == series && $0.part == part + 1 }
    }

    /// Swaps in an updated card (for example one that just got a quiz).
    func replace(_ card: Card) {
        if let i = cards.firstIndex(where: { $0.id == card.id }) { cards[i] = card }
    }

    var hasJapanese: Bool { shownCards.contains { $0.lang == "ja" } }

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
