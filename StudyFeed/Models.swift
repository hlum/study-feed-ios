import Foundation

// Mirrors docs/API.md. Decode with `JSONDecoder.studyFeed` (snake_case keys).
// Anything the server may omit is optional so one odd card never breaks the feed.

enum CardType: String, Codable {
    case poster, post, terminal
}

enum Topic: String, Codable, CaseIterable {
    case networking, security, ai, swe

    var title: String {
        switch self {
        case .networking: "Networking"
        case .security: "Security"
        case .ai: "AI"
        case .swe: "Software"
        }
    }
}

struct Card: Codable, Identifiable, Hashable {
    let id: Int
    let cardType: CardType
    let topic: Topic
    var seriesId: String?
    var part: Int?
    var partsTotal: Int?
    let title: String
    let body: String
    var source: Source?
    var slides: [Slide]?
    var visual: Visual?
    var cliffhanger: String?
    var quiz: Quiz?
    var flashcard: Flashcard?
    var deeper: String?
    var rare: Bool?
    var isReview: Bool?
    var previewIntervals: [String: String]?

    static func == (a: Card, b: Card) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }

    var isRare: Bool { rare ?? false }
}

struct Source: Codable, Hashable {
    var label: String?
    var quote: String?
    var url: String?
}

struct Slide: Codable, Hashable {
    var title: String?
    var body: String?
    var visual: Visual?
}

struct Quiz: Codable, Hashable {
    let question: String
    let options: [String]
    let answer: Int
    var explanation: String?
}

struct Flashcard: Codable, Hashable {
    let front: String
    let back: String
}

// MARK: Visuals

enum Visual: Codable, Hashable {
    case code(CodeVisual)
    case steps(StepsVisual)
    case terminal(TerminalVisual)
    /// Kinds the app has no native view for yet (mermaid, svg): the card still shows its text.
    case unsupported(String)

    private enum Key: String, CodingKey { case kind }

    init(from decoder: Decoder) throws {
        let kind = try decoder.container(keyedBy: Key.self).decode(String.self, forKey: .kind)
        switch kind {
        case "code": self = .code(try CodeVisual(from: decoder))
        case "steps": self = .steps(try StepsVisual(from: decoder))
        case "terminal": self = .terminal(try TerminalVisual(from: decoder))
        default: self = .unsupported(kind)
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .code(let v): try v.encode(to: encoder)
        case .steps(let v): try v.encode(to: encoder)
        case .terminal(let v): try v.encode(to: encoder)
        case .unsupported(let kind):
            var c = encoder.container(keyedBy: Key.self)
            try c.encode(kind, forKey: .kind)
        }
    }
}

struct CodeVisual: Codable, Hashable {
    var lang: String?
    let lines: [String]
    var notes: [CodeNote]?
}

struct CodeNote: Codable, Hashable {
    let line: Int
    let mark: String
    let text: String
}

struct StepsVisual: Codable, Hashable {
    let actors: [String]
    let steps: [Step]
}

struct Step: Codable, Hashable {
    let from: Int
    let to: Int
    let label: String
    var caption: String?
    var state: [String]?
}

struct TerminalVisual: Codable, Hashable {
    let command: String
    let lines: [String]
    var legend: [LegendItem]?
}

struct LegendItem: Codable, Hashable {
    let token: String
    let meaning: String
}

// MARK: Responses

struct FeedPage: Codable {
    let cards: [Card]
    var nextCursor: Int?
}

struct ReviewPage: Codable {
    let due: Int
    let cards: [Card]
}

struct AnswerResult: Codable {
    let correct: Bool
    let xp: Int
    var rareBonus: Bool?
    var level: Int?
    var levelXp: Int?
    var levelNext: Int?
    var leveledUp: Bool?
    var streak: Int?
    var badgesEarned: [String]?
}

struct ReviewResult: Codable {
    var nextDueAt: String?
    var intervalDays: Double?
}

struct Stats: Codable {
    let streak: Int
    let freezes: Int
    let todayDone: Bool
    let level: Int
    let levelXp: Int
    let levelNext: Int
    let weekCards: Int
    let lastWeekCards: Int
    let badges: [Badge]
}

struct Badge: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let earned: Bool
    var earnedAt: String?
}

struct StoriesResponse: Codable {
    let stories: [Story]
}

struct Story: Codable, Identifiable, Hashable {
    let topic: Topic
    let cardId: Int
    let preview: String
    let unseen: Bool
    var id: Int { cardId }
}

extension JSONDecoder {
    static let studyFeed: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()
}
