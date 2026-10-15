import Foundation

enum AskEvent: Equatable {
    case token(String)
    case suggestions([String])
    case done
}

/// Parses the server's event stream. Each event is `event: <name>` followed by one
/// `data: <json>` line, so an event is complete as soon as its data line arrives.
/// (URLSession's `lines` drops blank lines, so we can't wait for the usual blank separator.)
struct AskEventParser {
    private var event = ""

    mutating func feed(_ line: String) -> AskEvent? {
        if line.hasPrefix("event:") {
            event = line.dropFirst(6).trimmingCharacters(in: .whitespaces)
            return nil
        }
        guard line.hasPrefix("data:") else { return nil }
        let json = Data(line.dropFirst(5).trimmingCharacters(in: .whitespaces).utf8)
        defer { event = "" }
        switch event {
        case "token":
            struct Token: Decodable { let text: String }
            return (try? JSONDecoder().decode(Token.self, from: json)).map { .token($0.text) }
        case "suggestions":
            return .suggestions((try? JSONDecoder().decode([String].self, from: json)) ?? [])
        case "done":
            return .done
        default:
            return nil
        }
    }
}

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: String            // "user" | "assistant"
    var text: String
}

struct ThreadResponse: Decodable {
    struct Item: Decodable { let role: String; let text: String }
    let messages: [Item]
}

extension APIClient {
    func thread(cardId: Int) async throws -> [ChatMessage] {
        let url = try endpoint("/cards/\(cardId)/thread")
        let (data, response) = try await URLSession.shared.data(from: url)
        try validate(response)
        return try JSONDecoder.studyFeed.decode(ThreadResponse.self, from: data).messages
            .map { ChatMessage(role: $0.role, text: $0.text) }
    }

    /// Streams Claude's reply to a question about one card as it is written.
    func ask(cardId: Int, message: String) -> AsyncThrowingStream<AskEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var request = URLRequest(url: try endpoint("/ask"))
                    request.httpMethod = "POST"
                    request.timeoutInterval = 180   // Claude can think a while before the first token
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = try JSONSerialization.data(withJSONObject: ["card_id": cardId, "message": message])
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    try validate(response)
                    var parser = AskEventParser()
                    for try await line in bytes.lines {
                        if let event = parser.feed(line) { continuation.yield(event) }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
