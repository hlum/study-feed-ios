import SwiftUI

extension APIClient {
    /// The article's text as the server extracted it. Fetched on the first request, then saved.
    func reader(cardId: Int) async throws -> ReaderArticle {
        var request = URLRequest(url: try endpoint("/cards/\(cardId)/reader"))
        request.timeoutInterval = 45
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)
        return try JSONDecoder.studyFeed.decode(ReaderArticle.self, from: data)
    }
}

/// Reading view for an article: the text the server fetched, laid out for the phone,
/// with the original website one tap away. No model is involved.
struct ReaderSheet: View {
    @Environment(APIClient.self) private var api
    @Environment(\.dismiss) private var dismiss
    let card: Card

    private enum Phase { case loading, ready([String]), unavailable }
    @State private var phase = Phase.loading

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text([card.topic.title, card.siteName, card.age].compactMap { $0 }.joined(separator: " · "))
                        .font(.subheadline).foregroundStyle(Theme.muted)
                    Text(card.title)
                        .font(.system(.title2, weight: .bold)).tracking(card.tracking(-0.4))
                    content
                }
                .padding(.horizontal, 20).padding(.top, 28).padding(.bottom, 16)
            }
            VStack(spacing: 4) {
                SourceLink(source: card.source)
                Button { dismiss() } label: {
                    Text("Done").font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Theme.accent, in: Capsule()).foregroundStyle(Theme.onAccent)
                }
                .buttonStyle(PressStyle())
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 12)
        }
        .background(Theme.bg)
        .presentationBackground(Theme.bg)
        .presentationDragIndicator(.visible)
        .environment(\.locale, card.locale)
        .task { await load() }
    }

    @ViewBuilder private var content: some View {
        switch phase {
        case .loading:
            VStack(alignment: .leading, spacing: 10) {
                ProgressView().tint(Theme.accent)
                Text("Fetching the article.").font(.subheadline).foregroundStyle(Theme.muted)
            }
        case .ready(let paragraphs):
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, p in
                    // verbatim: the text comes from a web page, so nothing in it is interpreted.
                    Text(verbatim: p).font(.body).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                }
            }
        case .unavailable:
            VStack(alignment: .leading, spacing: 10) {
                if !card.body.isEmpty { Text(verbatim: card.body).font(.body) }
                Text("Couldn't build a reading view for this page. Open the website instead.")
                    .font(.subheadline).foregroundStyle(Theme.muted)
                Button("Try again") { Task { await load() } }
                    .buttonStyle(.bordered).tint(Theme.accent)
            }
        }
    }

    static func paragraphs(from text: String) -> [String] {
        text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func load() async {
        phase = .loading
        do {
            let article = try await api.reader(cardId: card.id)
            let paragraphs = article.text.map(Self.paragraphs) ?? []
            phase = paragraphs.isEmpty ? .unavailable : .ready(paragraphs)
        } catch {
            phase = .unavailable
        }
    }
}
