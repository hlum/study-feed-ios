import SwiftUI

private extension Card {
    var lessonLine: String? {
        guard let part, let partsTotal else { return nil }
        return "lesson \(part) of \(partsTotal)"
    }

    var metaLine: String {
        [topic.title, lessonLine ?? siteName].compactMap { $0 }.joined(separator: " · ")
    }
}

/// An article from a feed: its title and a little of its text. Tapping opens the reading view.
/// Nothing here was written by a model.
struct ArticleCard: View {
    let card: Card
    let onOpen: () -> Void

    private var meta: String {
        [card.topic.title, card.siteName, card.age].compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 10) {
                Text(meta).font(.subheadline).foregroundStyle(Theme.muted).lineLimit(1).padding(.trailing, 36)
                Text(card.title)
                    .font(.system(.title3, weight: .bold)).tracking(card.tracking(-0.3))
                    .multilineTextAlignment(.leading)
                if !card.body.isEmpty {
                    Text(card.body).font(.subheadline).foregroundStyle(Theme.muted)
                        .lineLimit(4).multilineTextAlignment(.leading)
                }
                Label("Read", systemImage: "arrow.up.right")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accent)
                    .frame(minHeight: 44, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Text post: concepts and news. Title, body, optional real quote, optional visual.
struct PostCard: View {
    let card: Card

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(card.metaLine).font(.subheadline).foregroundStyle(Theme.muted).padding(.trailing, 36)
            Text(card.title).font(.system(.title2, weight: .bold)).tracking(card.tracking(-0.4))
            Text(card.body).font(.body).foregroundStyle(Theme.ink.opacity(0.85))
            if let quote = card.source?.quote {
                VStack(alignment: .leading, spacing: 6) {
                    if let label = card.source?.label {
                        Text(label).font(.mono(.caption)).foregroundStyle(Theme.muted)
                    }
                    Text("\u{201C}\(quote)\u{201D}").font(.callout)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.sep))
            }
            SourceLink(source: card.source)
            if let visual = card.visual { VisualView(visual: visual) }
            Cliffhanger(card: card)
        }
    }
}

/// Terminal card: hands-on, the code or command output is the visual.
struct TerminalCard: View {
    let card: Card

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(card.metaLine).font(.subheadline).foregroundStyle(Theme.muted).padding(.trailing, 36)
            Text(card.title).font(.system(.title2, weight: .bold)).tracking(card.tracking(-0.4))
            if let visual = card.visual { VisualView(visual: visual) }
            Text(card.body).font(.body).foregroundStyle(Theme.ink.opacity(0.85))
            SourceLink(source: card.source)
            Cliffhanger(card: card)
        }
    }
}

/// Poster: swipeable slides on an accent card. Last slide carries the cliffhanger.
struct PosterCard: View {
    let card: Card
    @State private var page = 0

    private var slides: [Slide] { card.slides ?? [] }

    var body: some View {
        VStack(spacing: 10) {
            TabView(selection: $page) {
                cover.tag(0)
                ForEach(Array(slides.enumerated()), id: \.offset) { i, slide in
                    slideView(slide, isLast: i == slides.count - 1).tag(i + 1)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 28))
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .sensoryFeedback(.selection, trigger: page)

            HStack(spacing: 5) {
                ForEach(0...slides.count, id: \.self) { i in
                    Capsule().fill(i == page ? Theme.ink : Theme.sep)
                        .frame(width: i == page ? 16 : 6, height: 6)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 1), value: page)
        }
    }

    private var cover: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(card.metaLine).font(.subheadline.weight(.semibold)).opacity(0.75)
            Text(card.title)
                .font(.system(size: 36, weight: .heavy)).tracking(card.tracking(-1.2)).lineSpacing(card.isJapanese ? 2 : -2)
                .padding(.top, 20)
            Spacer(minLength: 12)
            Text(card.body).font(.body)
            Text("Swipe for the slides").font(.subheadline.weight(.semibold)).padding(.top, 14)
        }
        .foregroundStyle(Theme.onAccent)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 24).padding(.top, 24).padding(.bottom, 44)
    }

    private func slideView(_ slide: Slide, isLast: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let t = slide.title {
                Text(t).font(.system(size: 28, weight: .heavy)).tracking(card.tracking(-0.8))
            }
            if let b = slide.body { Text(b).font(.title3) }
            if let v = slide.visual {
                VisualView(visual: v)
                    .padding(12)
                    .background(Theme.bg, in: RoundedRectangle(cornerRadius: 18))
                    .environment(\.colorScheme, .dark)
            }
            Spacer(minLength: 0)
            if isLast, let c = card.cliffhanger {
                Text(c).font(.headline)
            }
        }
        .foregroundStyle(Theme.onAccent)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 24).padding(.top, 24).padding(.bottom, 44)
    }
}

/// Lets a card find and jump to the next part of its series in the feed.
struct SeriesNav {
    var next: (Card) -> Card? = { _ in nil }
    var jump: (Card) -> Void = { _ in }
}

private struct SeriesNavKey: EnvironmentKey {
    static let defaultValue = SeriesNav()
}

extension EnvironmentValues {
    var seriesNav: SeriesNav {
        get { self[SeriesNavKey.self] }
        set { self[SeriesNavKey.self] = newValue }
    }
}

/// The teaser question, and for a series card a way to read the answer: jump to the next
/// part when it's in the feed, otherwise say which part comes next.
struct Cliffhanger: View {
    let card: Card
    @Environment(\.seriesNav) private var nav

    var body: some View {
        if let text = card.cliffhanger {
            VStack(alignment: .leading, spacing: 4) {
                Text(text).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accent)
                if let part = card.part, let total = card.partsTotal, part < total {
                    if let next = nav.next(card) {
                        Button { nav.jump(next) } label: {
                            Label("Read part \(part + 1)", systemImage: "arrow.down")
                                .font(.subheadline.weight(.semibold))
                                .frame(minHeight: 44, alignment: .leading)
                        }
                        .buttonStyle(PressStyle())
                        .foregroundStyle(Theme.ink)
                    } else {
                        Text("Part \(part + 1) of \(total) is next").font(.footnote).foregroundStyle(Theme.muted)
                    }
                }
            }
            .padding(.top, 4)
        }
    }
}
