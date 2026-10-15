import UIKit

/// Hands a card to the ChatGPT app: a prompt with the brief and the source links is put on the
/// clipboard (so it can always be pasted) and opened as `chatgpt.com/?q=...`, a universal link
/// that opens the ChatGPT app when it's installed and the website otherwise.
enum ChatGPTHandoff {
    /// Most of a URL budget goes to the encoded prompt; this keeps the link comfortably openable.
    static let maxQueryCharacters = 1_500

    static func prompt(for card: Card) -> String {
        let ja = card.isJapanese
        var lines: [String] = []
        lines.append(ja
            ? "次のトピックについて、もっと深く理解したいです。"
            : "I'm learning about \(card.topic.title). Help me understand this topic more deeply.")
        lines.append("")
        lines.append((ja ? "トピック: " : "Topic: ") + card.title)
        lines.append((ja ? "要約: " : "Brief: ") + card.body)
        if let part = card.part, let total = card.partsTotal {
            lines.append(ja ? "シリーズ: 第\(part)回 / 全\(total)回" : "Series: lesson \(part) of \(total)")
        }
        if let quote = card.source?.quote, !quote.isEmpty {
            let label = card.source?.label.map { " (\($0))" } ?? ""
            lines.append((ja ? "出典の引用" : "Quote from the source") + label + ": \u{201C}\(quote)\u{201D}")
        }
        if let link = safeLink(card.source?.url) {
            lines.append((ja ? "出典: " : "Source: ") + link)
        }
        lines.append("")
        lines.append(ja
            ? "やさしく説明し、実際の例を1つ挙げ、よくある誤解を教えてください。次に読むべき資料を2つ提案してください。出典を明記し、確信がない部分はそう言ってください。"
            : "Explain it simply with one real example, tell me the most common misunderstanding, and suggest two things to read next. Cite your sources, and say so when you're unsure.")
        return lines.joined(separator: "\n")
    }

    /// Only plain web links go into the prompt: card text comes from the internet.
    private static func safeLink(_ raw: String?) -> String? {
        guard let raw, let url = URL(string: raw), ["http", "https"].contains(url.scheme?.lowercased()) else { return nil }
        return url.absoluteString
    }

    static func url(for prompt: String) -> URL? {
        // The instruction and source link sit at the end, so trim the brief in the middle if needed.
        let text = encode(prompt).count > maxQueryCharacters ? shortened(prompt) : prompt
        return URL(string: "https://chatgpt.com/?q=" + encode(text))
    }

    /// Keeps the first and last parts (topic, source, instruction) and trims the brief.
    private static func shortened(_ prompt: String) -> String {
        var lines = prompt.components(separatedBy: "\n")
        if let i = lines.firstIndex(where: { $0.hasPrefix("Brief: ") || $0.hasPrefix("要約: ") }) {
            var line = lines[i]
            while encode(lines.joined(separator: "\n")).count > maxQueryCharacters, line.count > 60 {
                line = String(line.dropLast(40))
                lines[i] = line + "…"
            }
        }
        return lines.joined(separator: "\n")
    }

    static func encode(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")) ?? ""
    }

    @MainActor static func copy(_ card: Card) {
        UIPasteboard.general.string = prompt(for: card)
    }

    /// Copies the full prompt, then opens ChatGPT with it.
    @MainActor static func open(_ card: Card) {
        let full = prompt(for: card)
        UIPasteboard.general.string = full
        guard let url = url(for: full) else { return }
        // Try the app first; if there's no app for the link, open the website instead.
        UIApplication.shared.open(url, options: [.universalLinksOnly: true]) { opened in
            if !opened { UIApplication.shared.open(url) }
        }
    }
}
