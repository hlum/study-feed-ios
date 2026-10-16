import Foundation
import Observation

struct CardList: Codable {
    let cards: [Card]
}

extension APIClient {
    func saved() async throws -> [Card] {
        let (data, response) = try await URLSession.shared.data(from: try endpoint("/saved"))
        try validate(response)
        return try JSONDecoder.studyFeed.decode(CardList.self, from: data).cards
    }
}

/// The cards you bookmarked. The server is the source of truth; changes show instantly here
/// and are rolled back if the server can't be reached.
@MainActor @Observable
final class SavedStore {
    private(set) var cards: [Card] = []
    private(set) var ids: Set<Int> = []
    var isLoading = false
    var error: String?

    @ObservationIgnored private let api: APIClient

    init(api: APIClient) { self.api = api }

    func isSaved(_ id: Int) -> Bool { ids.contains(id) }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            cards = try await api.saved()
            ids = Set(cards.map(\.id))
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func toggle(_ card: Card) {
        let wasSaved = ids.contains(card.id)
        apply(card, saved: !wasSaved)
        Task {
            do {
                try await api.setReaction(card.id, kind: "save", on: !wasSaved)
            } catch {
                apply(card, saved: wasSaved)   // couldn't reach the server: undo
                self.error = "Couldn't update your saved cards."
            }
        }
    }

    private func apply(_ card: Card, saved: Bool) {
        if saved {
            ids.insert(card.id)
            if !cards.contains(where: { $0.id == card.id }) { cards.insert(card, at: 0) }
        } else {
            ids.remove(card.id)
            cards.removeAll { $0.id == card.id }
        }
    }
}
