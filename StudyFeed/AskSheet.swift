import SwiftUI

@MainActor @Observable
final class AskStore {
    var messages: [ChatMessage] = []
    var suggestions: [String] = []
    var isStreaming = false
    var error: String?

    @ObservationIgnored private let api: APIClient
    @ObservationIgnored private let card: Card
    @ObservationIgnored private var streamTask: Task<Void, Never>?

    init(api: APIClient, card: Card) {
        self.api = api
        self.card = card
    }

    /// Starter questions for an empty thread, in the card's language.
    var starters: [String] {
        card.isJapanese
            ? ["もっと簡単に説明して", "実際の例を見せて", "なぜ重要なの？"]
            : ["Explain it simpler", "Show me a real example", "Why does this matter?"]
    }

    func load() async {
        do { messages = try await api.thread(cardId: card.id) }
        catch { self.error = error.localizedDescription }
    }

    func send(_ text: String) {
        let question = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isStreaming else { return }
        error = nil
        suggestions = []
        messages.append(ChatMessage(role: "user", text: question))
        messages.append(ChatMessage(role: "assistant", text: ""))
        isStreaming = true
        streamTask = Task {
            defer { isStreaming = false }
            do {
                for try await event in api.ask(cardId: card.id, message: question) {
                    switch event {
                    case .token(let t): messages[messages.count - 1].text += t
                    case .suggestions(let s): suggestions = s
                    case .done: break
                    }
                }
            } catch is CancellationError {
                return
            } catch {
                if messages.last?.text.isEmpty == true { messages.removeLast() }
                self.error = "Couldn't get an answer: \(error.localizedDescription)"
            }
        }
    }

    func stop() { streamTask?.cancel() }
}

struct AskSheet: View {
    @Environment(APIClient.self) private var api
    @Environment(\.dismiss) private var dismiss
    let card: Card

    var body: some View {
        AskContent(store: AskStore(api: api, card: card), card: card, dismiss: { dismiss() })
            .environment(\.locale, card.locale)
    }
}

private struct AskContent: View {
    @State var store: AskStore
    let card: Card
    let dismiss: () -> Void
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Theme.sep)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        if store.messages.isEmpty && !store.isStreaming { emptyHint }
                        ForEach(store.messages) { message in
                            bubble(message).id(message.id)
                        }
                        if let error = store.error {
                            Text(error).font(.footnote).foregroundStyle(Theme.wrong)
                        }
                        if !store.isStreaming { chips }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 12)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: store.messages.last?.text) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
                .onChange(of: store.messages.count) { _, _ in withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } }
            }
            inputBar
        }
        .background(Theme.bg)
        .presentationBackground(Theme.bg)
        .presentationDragIndicator(.visible)
        .task { await store.load() }
        .onDisappear { store.stop() }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Ask").font(.headline)
            Text(card.title).font(.subheadline).foregroundStyle(Theme.muted).lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 12)
    }

    private var emptyHint: some View {
        Text(card.isJapanese ? "このカードについて質問できます。" : "Ask anything about this card.")
            .font(.body).foregroundStyle(Theme.muted)
    }

    private func bubble(_ message: ChatMessage) -> some View {
        let isUser = message.role == "user"
        let isLast = message.id == store.messages.last?.id
        return VStack(alignment: .leading, spacing: 6) {
            Text(isUser ? "You" : "Claude").font(.subheadline.weight(.semibold))
                .foregroundStyle(isUser ? Theme.ink : Theme.accent)
            if message.text.isEmpty && store.isStreaming && isLast {
                ProgressView().tint(Theme.accent)
            } else {
                RichText(text: message.text, streaming: store.isStreaming && isLast && !isUser)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var chips: some View {
        let items = store.messages.isEmpty ? store.starters : followUps
        if !items.isEmpty {
            FlowLayout(spacing: 8) {
                ForEach(items, id: \.self) { text in
                    Button { store.send(text) } label: {
                        Text(text).font(.subheadline)
                            .padding(.horizontal, 14).frame(height: 38)
                            .overlay(Capsule().stroke(Theme.sep))
                            .foregroundStyle(Theme.ink)
                    }
                    .buttonStyle(PressStyle())
                }
            }
        }
    }

    /// The server's follow-ups, plus a flashcard shortcut once there is something to save.
    private var followUps: [String] {
        var items = store.suggestions
        let flashcard = "Make it a flashcard"
        if !store.messages.isEmpty, !items.contains(flashcard) { items.append(flashcard) }
        return items
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Ask a follow-up", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .focused($focused)
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(Theme.fill, in: RoundedRectangle(cornerRadius: 22))
                .submitLabel(.send)
                .onSubmit(send)
            Button(action: send) {
                Image(systemName: "arrow.up").font(.headline.weight(.bold))
                    .frame(width: 44, height: 44)
                    .background(canSend ? Theme.accent : Theme.fill, in: Circle())
                    .foregroundStyle(canSend ? Theme.onAccent : Theme.muted)
            }
            .disabled(!canSend)
            .accessibilityLabel("Send")
        }
        .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 12)
        .overlay(alignment: .top) { Divider().overlay(Theme.sep) }
    }

    private var canSend: Bool { !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !store.isStreaming }

    private func send() {
        guard canSend else { return }
        store.send(draft)
        draft = ""
    }
}

/// Plain text with `inline markdown` and fenced code blocks, the two things replies use.
struct RichText: View {
    let text: String
    var streaming = false

    private var parts: [(isCode: Bool, text: String)] {
        text.components(separatedBy: "```").enumerated().compactMap { i, part in
            if i % 2 == 1 {
                // Drop the language tag on the fence line.
                let lines = part.split(separator: "\n", omittingEmptySubsequences: false)
                return (true, lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .newlines))
            }
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : (false, trimmed)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(parts.enumerated()), id: \.offset) { i, part in
                if part.isCode {
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(part.text).font(.mono(.footnote)).fixedSize()
                            .padding(14)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.fill, in: RoundedRectangle(cornerRadius: 12))
                } else {
                    (Text(markdown(part.text)) + (streaming && i == parts.count - 1 ? Text(" ▍").foregroundColor(Theme.accent) : Text("")))
                        .font(.body).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func markdown(_ s: String) -> AttributedString {
        (try? AttributedString(markdown: s, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(s)
    }
}
