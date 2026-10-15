import Foundation
import Observation

@MainActor @Observable
final class FeedStore {
    var cards: [Card] = []
    var stories: [Story] = []
    var stats: Stats?
    var error: String?
    var isLoading = false

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

    func reloadStats() async {
        stats = (try? await api.stats()) ?? stats
        if let stats { Reminder.update(with: stats) }
    }

    /// Call as a card appears; loads the next page when the reader is near the end.
    func cardAppeared(_ card: Card) async {
        guard !reachedEnd, !isLoading, let index = cards.firstIndex(of: card), index >= cards.count - 3 else { return }
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
