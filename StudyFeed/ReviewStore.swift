import Foundation
import Observation

enum Rating: String, CaseIterable {
    case again, hard, good, easy

    var title: String { rawValue.capitalized }
}

/// The spaced-repetition queue: cards the server says are due now.
@MainActor @Observable
final class ReviewStore {
    private(set) var cards: [Card] = []
    private(set) var total = 0
    private(set) var index = 0
    var showingAnswer = false
    var isLoading = false
    var error: String?

    @ObservationIgnored private let api: APIClient
    /// `-demoReview` launch argument (debug builds): borrow feed cards, send nothing to the server.
    @ObservationIgnored private let demo: Bool

    init(api: APIClient) {
        self.api = api
        #if DEBUG
        demo = CommandLine.arguments.contains("-demoReview")
        #else
        demo = false
        #endif
    }

    var current: Card? { cards[safe: index] }
    var dueCount: Int { max(total - index, 0) }
    var isFinished: Bool { total > 0 && index >= cards.count }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            if demo {
                cards = try await api.feed(cursor: nil, limit: 3).cards
                total = cards.count
            } else {
                let page = try await api.review()
                cards = page.cards
                total = page.due
            }
            index = 0
            showingAnswer = false
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func rate(_ rating: Rating) {
        guard let card = current else { return }
        showingAnswer = false
        index += 1
        guard !demo else { return }
        Task {
            do { _ = try await api.rate(card.id, rating: rating.rawValue) }
            catch { self.error = "Couldn't save that rating. It will show up again." }
        }
    }

    /// Text for the interval under each rating button, as the server previewed it.
    func interval(for rating: Rating, on card: Card) -> String? {
        if let preview = card.previewIntervals?[rating.rawValue] { return preview }
        #if DEBUG
        if demo { return ["again": "10 min", "hard": "2 days", "good": "6 days", "easy": "2 weeks"][rating.rawValue] }
        #endif
        return nil
    }
}

extension Card {
    /// What to ask and what to show: the flashcard if the card has one, else its quiz.
    var reviewFront: String { flashcard?.front ?? quiz?.question ?? title }

    var reviewBack: String {
        if let flashcard { return flashcard.back }
        if let quiz, quiz.options.indices.contains(quiz.answer) {
            return [quiz.options[quiz.answer], quiz.explanation].compactMap { $0 }.joined(separator: "\n\n")
        }
        return body
    }
}
