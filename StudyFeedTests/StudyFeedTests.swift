import Foundation
import Testing
@testable import StudyFeed

/// Decodes real responses saved from the live server (Fixtures/), so a server
/// change that the app can't read shows up here before it shows up on the phone.
struct FixtureDecodingTests {
    private func load<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/\(name).json")
        return try JSONDecoder.studyFeed.decode(T.self, from: Data(contentsOf: url))
    }

    @Test func feedDecodesWithEveryCardTypeAndVisual() throws {
        let page = try load("feed", as: FeedPage.self)
        #expect(page.cards.count > 0)
        #expect(Set(page.cards.map(\.cardType)).count == 3)

        var kinds = Set<String>()
        for card in page.cards {
            for v in [card.visual] + (card.slides ?? []).map(\.visual) {
                switch v {
                case .code: kinds.insert("code")
                case .steps: kinds.insert("steps")
                case .terminal: kinds.insert("terminal")
                case .unsupported(let k): kinds.insert(k)
                case nil: break
                }
            }
            #expect(card.quiz?.options.count == 4)
        }
        #expect(kinds.isSuperset(of: ["code", "steps", "terminal"]))
    }

    @Test func statsReviewAndStoriesDecode() throws {
        let stats = try load("stats", as: Stats.self)
        #expect(stats.levelNext > 0)
        #expect(stats.badges.count > 0)
        _ = try load("review", as: ReviewPage.self)
        #expect(try load("stories", as: StoriesResponse.self).stories.count > 0)
    }

    @Test func answerResultDecodesTheDocumentedShape() throws {
        let json = """
        {"correct": true, "xp": 20, "rare_bonus": true, "level": 7, "level_xp": 360,
         "level_next": 400, "leveled_up": false, "streak": 12, "badges_earned": ["first-rare-card"]}
        """
        let r = try JSONDecoder.studyFeed.decode(AnswerResult.self, from: Data(json.utf8))
        #expect(r.correct && r.xp == 20 && r.rareBonus == true && r.levelNext == 400)
        // Only the two required fields: everything else may be missing.
        let minimal = try JSONDecoder.studyFeed.decode(AnswerResult.self, from: Data(#"{"correct":false,"xp":0}"#.utf8))
        #expect(!minimal.correct && minimal.level == nil)
    }
}
