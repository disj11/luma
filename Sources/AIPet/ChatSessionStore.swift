import Foundation

struct ChatSession: Codable, Identifiable {
    var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var messages: [ChatMessage]

    static func empty() -> ChatSession {
        let now = Date()
        return ChatSession(
            id: UUID(),
            title: "새 대화",
            createdAt: now,
            updatedAt: now,
            messages: []
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
