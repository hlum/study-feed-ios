import SwiftUI

extension APIClient {
    /// Longer explanation behind a card. The server writes it on the first request (slow, one
    /// Claude call) and saves it, so every later request is instant.
    func deeper(cardId: Int) async throws -> String {
        struct Body: Decodable { let markdown: String }
        var request = URLRequest(url: try endpoint("/cards/\(cardId)/deeper"))
        request.timeoutInterval = 120
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)
        return try JSONDecoder.studyFeed.decode(Body.self, from: data).markdown
    }
}

/// Remembers what was fetched this session so reopening a sheet never asks again.
@MainActor enum DeeperCache {
    static var articles: [Int: String] = [:]
}

struct DeeperSheet: View {
    @Environment(APIClient.self) private var api
    @Environment(\.dismiss) private var dismiss
    let card: Card

    @State private var markdown: String?
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("\(card.topic.title) · go deeper").font(.subheadline).foregroundStyle(Theme.muted)
                    // The article opens with its own headline; show the card's title until then.
                    if markdown?.hasPrefix("#") != true {
                        Text(card.title)
                            .font(.system(.title2, weight: .bold)).tracking(card.tracking(-0.4))
                    }
                    if let markdown {
                        RichText(text: markdown)
                    } else if let error {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(error).foregroundStyle(Theme.muted)
                            Button("Try again") { Task { await load() } }
                                .buttonStyle(.borderedProminent).tint(Theme.accent).foregroundStyle(Theme.onAccent)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            ProgressView().tint(Theme.accent)
                            Text("Writing this for you. The first time takes a few seconds.")
                                .font(.subheadline).foregroundStyle(Theme.muted)
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.top, 28).padding(.bottom, 24)
            }
            Button { dismiss() } label: {
                Text("Done").font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Theme.accent, in: Capsule()).foregroundStyle(Theme.onAccent)
            }
            .buttonStyle(PressStyle())
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 12)
        }
        .background(Theme.bg)
        .presentationBackground(Theme.bg)
        .presentationDragIndicator(.visible)
        .environment(\.locale, card.locale)
        .task {
            markdown = card.deeper.flatMap { $0.isEmpty ? nil : $0 } ?? DeeperCache.articles[card.id]
            if markdown == nil { await load() }
        }
    }

    private func load() async {
        error = nil
        do {
            let text = try await api.deeper(cardId: card.id)
            DeeperCache.articles[card.id] = text
            markdown = text
        } catch {
            self.error = "Couldn't load this: \(error.localizedDescription)"
        }
    }
}
