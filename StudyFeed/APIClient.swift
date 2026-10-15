import Foundation
import Observation

enum APIError: LocalizedError {
    case notConfigured, badURL, badStatus(Int)

    var errorDescription: String? {
        switch self {
        case .notConfigured: "Set your server address in the You tab."
        case .badURL: "The server address isn't a valid URL."
        case .badStatus(let code): "The server answered \(code)."
        }
    }
}

/// Talks to the Study Feed server (docs/API.md). The address is a user setting,
/// never hard-coded: the server is only reachable over the user's tailnet.
/// A `-serverURL <url>` launch argument also sets it (handy for simulator runs).
@MainActor @Observable
final class APIClient {
    var baseURL: String {
        didSet { UserDefaults.standard.set(baseURL, forKey: "serverURL") }
    }

    @ObservationIgnored private let session: URLSession

    init() {
        let saved = UserDefaults.standard.string(forKey: "serverURL") ?? ""
        // A launch-argument value lives only in the argument domain; keep it for next launch.
        if !saved.isEmpty { UserDefaults.standard.set(saved, forKey: "serverURL") }
        baseURL = saved
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        session = URLSession(configuration: config)
    }

    // MARK: Endpoints

    func feed(cursor: Int?, limit: Int = 10) async throws -> FeedPage {
        var q = ["limit": String(limit)]
        if let cursor { q["cursor"] = String(cursor) }
        return try await get("/feed", query: q)
    }

    func stories() async throws -> [Story] {
        try await get("/stories", as: StoriesResponse.self).stories
    }

    func stats() async throws -> Stats { try await get("/stats") }

    func review() async throws -> ReviewPage { try await get("/review") }

    func markSeen(_ cardId: Int) async {
        _ = try? await post("/seen", ["card_id": cardId]) as Data
    }

    func react(_ cardId: Int, kind: String, on: Bool) async {
        _ = try? await post("/react", ["card_id": cardId, "kind": kind, "on": on]) as Data
    }

    func answer(_ cardId: Int, choice: Int) async throws -> AnswerResult {
        let data: Data = try await post("/answer", ["card_id": cardId, "choice": choice])
        return try JSONDecoder.studyFeed.decode(AnswerResult.self, from: data)
    }

    func rate(_ cardId: Int, rating: String) async throws -> ReviewResult {
        let data: Data = try await post("/review", ["card_id": cardId, "rating": rating])
        return try JSONDecoder.studyFeed.decode(ReviewResult.self, from: data)
    }

    // MARK: Plumbing

    func endpoint(_ path: String) throws -> URL { try makeURL(path) }

    private func makeURL(_ path: String, _ query: [String: String] = [:]) throws -> URL {
        let base = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty else { throw APIError.notConfigured }
        guard var c = URLComponents(string: base + path) else { throw APIError.badURL }
        if !query.isEmpty { c.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) } }
        guard let url = c.url else { throw APIError.badURL }
        return url
    }

    nonisolated func validate(_ response: URLResponse) throws { try check(response) }

    nonisolated private func check(_ response: URLResponse) throws {
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw APIError.badStatus(http.statusCode)
        }
    }

    private func get<T: Decodable>(_ path: String, query: [String: String] = [:], as type: T.Type = T.self) async throws -> T {
        let (data, response) = try await session.data(from: makeURL(path, query))
        try check(response)
        return try JSONDecoder.studyFeed.decode(T.self, from: data)
    }

    private func post(_ path: String, _ body: [String: Any]) async throws -> Data {
        var request = URLRequest(url: try makeURL(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        try check(response)
        return data
    }
}
