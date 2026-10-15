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

    @Test func askEventStreamParsesTokensSuggestionsAndDone() {
        var parser = AskEventParser()
        let lines = [
            "event: token", #"data: {"text": "Because "}"#,
            "event: token", #"data: {"text": "日本語もOK\n"}"#,
            "event: suggestions", #"data: ["What's a SYN flood?", "Make it a flashcard"]"#,
            "event: done", "data: {}",
        ]
        let events = lines.compactMap { parser.feed($0) }
        #expect(events == [
            .token("Because "), .token("日本語もOK\n"),
            .suggestions(["What's a SYN flood?", "Make it a flashcard"]), .done,
        ])
        // Unknown events and garbage are ignored, never crash the stream.
        #expect(parser.feed("event: ping") == nil)
        #expect(parser.feed("data: not json") == nil)
    }

    @Test func richTextSplitsHeadingsParagraphsAndCode() {
        let md = "## Why it works\n\nFirst line\nsecond line\n\n```swift\nlet x = 1\n```\n\nafter"
        #expect(RichText.blocks(from: md) == [
            .heading("Why it works"), .paragraph("First line\nsecond line"), .code("let x = 1"), .paragraph("after"),
        ])
        // An unfinished fence while streaming is still shown as code, not lost.
        #expect(RichText.blocks(from: "text\n```py\nprint(1)") == [.paragraph("text"), .code("print(1)")])
    }

    @MainActor @Test func flashcardCanOnlyBeRequestedOncePerThread() async throws {
        let card = try JSONDecoder.studyFeed.decode(Card.self, from: Data(
            #"{"id": 5, "card_type": "post", "topic": "ai", "title": "t", "body": "b"}"#.utf8))
        let store = AskStore(api: APIClient(), card: card)
        #expect(!store.flashcardSaved)
        store.messages = [
            ChatMessage(role: "user", text: "Make it a flashcard"),
            ChatMessage(role: "assistant", text: "Sorry, I couldn't make a flashcard right now. Try again later."),
        ]
        #expect(!store.flashcardSaved)   // a failed attempt can be retried
        store.messages[1].text = "Saved as a flashcard (card 31). It shows up in Review tomorrow."
        #expect(store.flashcardSaved)
        let before = store.messages.count
        store.send("Make it a flashcard")
        #expect(store.messages.count == before)   // blocked: nothing sent, no second Claude call
    }

    @Test func chatGPTPromptCarriesBriefAndOnlyWebSourceLinks() throws {
        let card = try JSONDecoder.studyFeed.decode(Card.self, from: Data("""
            {"id": 7, "card_type": "post", "topic": "security", "title": "A zip entry can write anywhere",
             "body": "Resolve the path before extracting.", "part": 2, "parts_total": 8,
             "source": {"label": "PortSwigger Research", "quote": "It wrote outside the folder.",
                        "url": "https://portswigger.net/research/zip"}}
            """.utf8))
        let prompt = ChatGPTHandoff.prompt(for: card)
        #expect(prompt.contains("A zip entry can write anywhere"))
        #expect(prompt.contains("Resolve the path before extracting."))
        #expect(prompt.contains("Source: https://portswigger.net/research/zip"))
        #expect(prompt.contains("lesson 2 of 8"))

        // A link that isn't plain http(s) never reaches the prompt.
        var bad = card
        bad.source = Source(label: "x", quote: nil, url: "javascript:alert(1)")
        #expect(!ChatGPTHandoff.prompt(for: bad).contains("javascript:"))

        // The link round-trips through the URL, and a long brief is trimmed to fit.
        var long = card
        long = try JSONDecoder.studyFeed.decode(Card.self, from: Data("""
            {"id": 8, "card_type": "post", "topic": "ai", "title": "t",
             "body": "\(String(repeating: "word ", count: 600))",
             "source": {"url": "https://example.com/a?b=1&c=2"}}
            """.utf8))
        let url = try #require(ChatGPTHandoff.url(for: ChatGPTHandoff.prompt(for: long)))
        #expect(url.host == "chatgpt.com")
        let q = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "q" }?.value)
        #expect(q.contains("Source: https://example.com/a?b=1&c=2"))
        #expect(url.absoluteString.count < 1_700)

        // No article link: say so, never invent one.
        var none = card
        none.source = nil
        let noLink = ChatGPTHandoff.prompt(for: none)
        #expect(noLink.contains("no article link") && !noLink.contains("http"))
    }

    @Test func japaneseCardsGetAJapanesePrompt() throws {
        let card = try JSONDecoder.studyFeed.decode(Card.self, from: Data(
            #"{"id": 9, "card_type": "post", "topic": "ios", "lang": "ja", "title": "SwiftUIの状態管理", "body": "本文"}"#.utf8))
        let prompt = ChatGPTHandoff.prompt(for: card)
        #expect(prompt.contains("トピック: SwiftUIの状態管理") && prompt.contains("やさしく説明"))
    }

    @MainActor @Test func nextPartIsFoundOnlyWhenItIsInTheFeed() throws {
        func card(_ id: Int, _ series: String?, _ part: Int?) throws -> Card {
            let s = series.map { #", "series_id": "\#($0)", "part": \#(part!), "parts_total": 3"# } ?? ""
            return try JSONDecoder.studyFeed.decode(Card.self, from: Data(
                #"{"id": \#(id), "card_type": "post", "topic": "ai", "title": "t", "body": "b"\#(s)}"#.utf8))
        }
        let store = FeedStore(api: APIClient())
        store.cards = [try card(1, "tcp", 1), try card(2, "dns", 2), try card(3, "tcp", 2), try card(4, nil, nil)]
        #expect(store.nextPart(of: store.cards[0])?.id == 3)   // same series, next part
        #expect(store.nextPart(of: store.cards[2]) == nil)     // part 3 isn't loaded yet
        #expect(store.nextPart(of: store.cards[3]) == nil)     // news has no series
    }

    @MainActor @Test func sitesRowNarrowsToTheOtherFilters() throws {
        func card(_ id: Int, _ site: String, lang: String) throws -> Card {
            try JSONDecoder.studyFeed.decode(Card.self, from: Data(
                #"{"id": \#(id), "card_type": "post", "topic": "ai", "lang": "\#(lang)", "title": "t", "body": "b", "source": {"label": "\#(site)"}}"#.utf8))
        }
        let store = FeedStore(api: APIClient())
        store.cards = [try card(1, "Krebs", lang: "en"), try card(2, "Zenn", lang: "ja"), try card(3, "Qiita", lang: "ja")]
        #expect(Set(store.sites.map(\.name)) == ["Krebs", "Zenn", "Qiita"])
        store.filter.japanese = true
        #expect(Set(store.sites.map(\.name)) == ["Zenn", "Qiita"])           // only Japanese sites
        store.filter.siteKeys = ["krebs"]                                      // a chosen site stays listed
        #expect(store.sites.contains { $0.key == "krebs" })
    }
}
