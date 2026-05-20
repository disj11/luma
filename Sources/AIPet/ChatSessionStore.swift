import Foundation

struct ChatSession: Codable, Identifiable {
    var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var messages: [ChatMessage]
    var summary: String

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case createdAt
        case updatedAt
        case messages
        case summary
    }

    init(id: UUID, title: String, createdAt: Date, updatedAt: Date, messages: [ChatMessage], summary: String = "") {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messages = messages
        self.summary = summary
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        messages = try container.decode([ChatMessage].self, forKey: .messages)
        summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
    }

    static func empty() -> ChatSession {
        let now = Date()
        return ChatSession(
            id: UUID(),
            title: "새 대화",
            createdAt: now,
            updatedAt: now,
            messages: [],
            summary: ""
        )
    }
}

final class ChatSessionStore {
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    var sessionsDirectory: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Luma/ChatSessions", isDirectory: true)
    }

    func loadSessions() -> [ChatSession] {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: sessionsDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return urls
            .filter { $0.pathExtension == "json" }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(ChatSession.self, from: data)
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func save(_ session: ChatSession) {
        try? fileManager.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)
        guard let data = try? encoder.encode(session) else { return }
        try? data.write(to: fileURL(for: session.id), options: [.atomic])
    }

    func delete(_ session: ChatSession) {
        try? fileManager.removeItem(at: fileURL(for: session.id))
    }

    private func fileURL(for id: UUID) -> URL {
        sessionsDirectory.appendingPathComponent("\(id.uuidString).json")
    }
}
