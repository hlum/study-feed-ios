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

    @Test func reviewCardsCarryIntervalPreviewsAndFallBackToTheQuiz() throws {
        let json = """
        {"due": 1, "cards": [{"id": 9, "card_type": "post", "topic": "networking", "title": "t", "body": "b",
          "quiz": {"question": "Q?", "options": ["w", "right", "x", "y"], "answer": 1, "explanation": "because"},
          "is_review": true,
          "preview_intervals": {"again": "10 min", "hard": "2 days", "good": "6 days", "easy": "2 weeks"}}]}
        """
        let page = try JSONDecoder.studyFeed.decode(ReviewPage.self, from: Data(json.utf8))
        let card = try #require(page.cards.first)
        #expect(card.previewIntervals?["good"] == "6 days")
        #expect(card.reviewFront == "Q?")
        #expect(card.reviewBack == "right\n\nbecause")
    }

    @Test func unknownTopicAndCardTypeStillDecodeAndFiltersWork() throws {
        func card(_ extra: String) -> String {
            """
            {"id": 1, "card_type": "carousel", "topic": "ios", "title": "t", "body": "b"\(extra)}
            """
        }
        let ios = try JSONDecoder.studyFeed.decode(Card.self, from: Data(card("").utf8))
        #expect(ios.topic.title == "iOS" && ios.cardType == .post)
        #expect(ios.resolvedKind == "news")   // no series, so it came from an article

        let lesson = try JSONDecoder.studyFeed.decode(Card.self, from: Data(card(#", "series_id": "swiftui""#).utf8))
        #expect(lesson.resolvedKind == "lesson" && lesson.siteName == nil)

        let krebsA = try JSONDecoder.studyFeed.decode(Card.self, from: Data(card(#", "source": {"label": "KrebsOnSecurity"}"#).utf8))
        let krebsB = try JSONDecoder.studyFeed.decode(Card.self, from: Data(card(#", "source": {"label": "Krebs on Security"}"#).utf8))
        #expect(krebsA.siteKey == krebsB.siteKey)

        var filter = FeedFilter()
        filter.kind = "lesson"
        #expect(filter.matches(lesson) && !filter.matches(ios))
        filter = FeedFilter(topics: [Topic(rawValue: "ios")], japanese: true)
        #expect(!filter.matches(ios))   // not tagged Japanese

        // Several topics and several sites: any one of each group matches.
        filter = FeedFilter(topics: [Topic(rawValue: "ios"), .security], siteKeys: [krebsA.siteKey!, "zenn"])
        #expect(!filter.matches(ios))                    // right topic, but no site
        #expect(!filter.matches(lesson))                 // a lesson has no site
        let krebsIOS = try JSONDecoder.studyFeed.decode(Card.self, from: Data(card(#", "source": {"label": "Zenn"}"#).utf8))
        #expect(filter.matches(krebsIOS))                // ios topic and Zenn site
    }

    @Test func japaneseCardsGetNeutralTrackingAndJapaneseLocale() throws {
        let ja = try JSONDecoder.studyFeed.decode(Card.self, from: Data(
            #"{"id": 2, "card_type": "post", "topic": "ios", "lang": "ja", "title": "SwiftUIの状態管理", "body": "本文"}"#.utf8))
        #expect(ja.isJapanese && ja.tracking(-1.2) == 0)
        #expect(ja.locale.identifier == "ja_JP")
        let en = try JSONDecoder.studyFeed.decode(Card.self, from: Data(
            #"{"id": 3, "card_type": "post", "topic": "ios", "title": "t", "body": "b"}"#.utf8))
        #expect(!en.isJapanese && en.tracking(-1.2) == -1.2)
    }
}
