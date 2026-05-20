import Foundation

struct ChatMessage: Codable {
    let role: String
    let content: String
}

struct ChatRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
}

struct ChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}

final class AIClient {
    private let settings: SettingsStore

    init(settings: SettingsStore) {
        self.settings = settings
    }

    func send(messages: [ChatMessage], completion: @escaping (Result<String, Error>) -> Void) {
        do {
            let request = try makeRequest(messages: messages)
            URLSession.shared.dataTask(with: request) { data, _, error in
                if let error {
                    completion(.failure(error))
                    return
                }
                guard let data else {
                    completion(.failure(AIClientError.emptyResponse))
                    return
                }
                do {
                    let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
                    completion(.success(decoded.choices.first?.message.content ?? "응답이 비어 있어요."))
                } catch {
                    let body = String(data: data, encoding: .utf8) ?? ""
                    completion(.failure(AIClientError.invalidResponse(body)))
                }
            }.resume()
        } catch {
            completion(.failure(error))
        }
    }

    private func makeRequest(messages: [ChatMessage]) throws -> URLRequest {
        guard !settings.endpoint.isEmpty else {
            throw AIClientError.missingEndpoint
        }
        guard var components = URLComponents(string: settings.endpoint) else {
            throw AIClientError.invalidEndpoint
        }

        if !components.path.hasSuffix("/chat/completions") {
            components.path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/v1/chat/completions"
            if !components.path.hasPrefix("/") {
                components.path = "/" + components.path
            }
        }

        guard let url = components.url else {
            throw AIClientError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if !settings.apiKey.isEmpty {
            request.addValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization")
        }

        let payload = ChatRequest(
            model: settings.model.isEmpty ? "gpt-4o-mini" : settings.model,
            messages: [
                ChatMessage(role: "system", content: systemPrompt()),
            ] + Array(messages.suffix(24)),
            temperature: 0.8
        )
        request.httpBody = try JSONEncoder().encode(payload)
        return request
    }

    private func systemPrompt() -> String {
        """
        \(settings.persona)

        행동 원칙:
        - 페르소나는 말투와 정서 표현에만 적용한다. 사용자가 요청한 실제 과업을 회피하거나 축소하지 않는다.
        - 장소, 맛집, 일정, 최신 정보, 제품, 가격, 뉴스처럼 현재성이 있거나 외부 정보가 필요한 요청은 가능한 경우 실제 검색/도구/연결된 API의 지식을 사용해 구체적인 결과를 제공한다.
        - 정보를 찾는 요청에 단순 잡담, 역할극, 응원만으로 답하지 않는다.
        - 확실하지 않은 정보는 확실한 척하지 말고, 확인 필요 여부와 한계를 짧게 밝힌다.
        - 한국어 사용자를 우선한다. 한국의 장소나 서비스 요청은 한국어 이름, 위치 단서, 선택 이유를 간결하게 정리한다.
        - 답변은 캐릭터의 말투를 유지하되, 정보의 정확성과 유용성을 귀여움보다 우선한다.
        """
    }
}

enum AIClientError: LocalizedError {
    case missingEndpoint
    case invalidEndpoint
    case emptyResponse
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .missingEndpoint:
            return "설정에서 API 엔드포인트를 먼저 입력해주세요."
        case .invalidEndpoint:
            return "API 엔드포인트 URL을 해석할 수 없어요."
        case .emptyResponse:
            return "서버 응답이 비어 있어요."
        case .invalidResponse(let body):
            return "응답 형식이 예상과 달라요: \(body.prefix(300))"
        }
    }
}
