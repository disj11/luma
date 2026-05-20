import Foundation

struct SearchResult {
    var title: String
    var url: String
    var snippet: String
}

final class SearchClient {
    private let settings: SettingsStore

    init(settings: SettingsStore) {
        self.settings = settings
    }

    var isConfigured: Bool {
        !settings.searchEndpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @discardableResult
    func search(query: String, completion: @escaping (Result<[SearchResult], Error>) -> Void) -> URLSessionDataTask? {
        guard var components = URLComponents(string: settings.searchEndpoint) else {
            completion(.failure(SearchError.invalidEndpoint))
            return nil
        }

        var items = components.queryItems ?? []
        if !items.contains(where: { $0.name == "q" || $0.name == "query" }) {
            items.append(URLQueryItem(name: "q", value: query))
        }
        components.queryItems = items

        guard let url = components.url else {
            completion(.failure(SearchError.invalidEndpoint))
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        if !settings.searchApiKey.isEmpty {
            let header = settings.searchApiKeyHeader.trimmingCharacters(in: .whitespacesAndNewlines)
            request.addValue(searchAuthorizationValue(for: header), forHTTPHeaderField: header.isEmpty ? "Authorization" : header)
        }

        let task = URLSession.shared.dataTask(with: request) { data, _, error in
            if let error {
                completion(.failure(error))
                return
            }
            guard let data else {
                completion(.failure(SearchError.emptyResponse))
                return
            }

            do {
                let object = try JSONSerialization.jsonObject(with: data)
                completion(.success(Self.parseResults(from: object)))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
        return task
    }

    private static func parseResults(from object: Any) -> [SearchResult] {
        let arrays = candidateArrays(from: object)
        for array in arrays {
            let results = array.compactMap(parseResult).prefix(8)
            if !results.isEmpty {
                return Array(results)
            }
        }
        return []
    }

    private static func candidateArrays(from object: Any) -> [[Any]] {
        if let array = object as? [Any] {
            return [array]
        }
        guard let dictionary = object as? [String: Any] else {
            return []
        }

        let keys = ["results", "organic", "items", "webPages", "documents"]
        var arrays: [[Any]] = []
        for key in keys {
            if let array = dictionary[key] as? [Any] {
                arrays.append(array)
            } else if let nested = dictionary[key] as? [String: Any],
                      let value = nested["value"] as? [Any] {
                arrays.append(value)
            } else if let nested = dictionary[key] as? [String: Any],
                      let results = nested["results"] as? [Any] {
                arrays.append(results)
            }
        }

        for key in ["web", "news", "places", "local"] {
            guard let nested = dictionary[key] as? [String: Any] else { continue }
            if let results = nested["results"] as? [Any] {
                arrays.append(results)
            }
        }
        return arrays
    }

    private static func parseResult(_ object: Any) -> SearchResult? {
        guard let dictionary = object as? [String: Any] else { return nil }
        let title = firstString(in: dictionary, keys: ["title", "name", "headline"])
        let url = firstString(in: dictionary, keys: ["url", "link", "href"])
        let snippet = firstString(in: dictionary, keys: ["snippet", "content", "description", "summary", "text"]) ?? ""

        guard let title, let url else { return nil }
        return SearchResult(title: title, url: url, snippet: snippet)
    }

    private static func firstString(in dictionary: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = dictionary[key] as? String,
               !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value
            }
        }
        return nil
    }

    private func searchAuthorizationValue(for header: String) -> String {
        let key = settings.searchApiKey
        guard header.isEmpty || header.caseInsensitiveCompare("Authorization") == .orderedSame else {
            return key
        }
        if key.localizedCaseInsensitiveContains("Bearer ") {
            return key
        }
        return "Bearer \(key)"
    }
}

enum SearchError: LocalizedError {
    case invalidEndpoint
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            return "검색 엔드포인트 URL을 해석할 수 없어요."
        case .emptyResponse:
            return "검색 응답이 비어 있어요."
        }
    }
}
