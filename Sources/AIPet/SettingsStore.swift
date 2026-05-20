import Foundation
import Security

final class SettingsStore {
    private static let legacyRibbonPersona = "너는 사용자의 macOS 바탕화면 위를 돌아다니는 작은 여성형 chibi 데스크톱 메이트야. 빨간 리본과 별 가방이 시그니처 포인트이며, 한국어로 친절하고 짧게 답하되 밝고 장난스러운 말투를 사용해."
    private static let lunaSeraPersona = "너는 사용자의 macOS 화면 위를 돌아다니는 오리지널 판타지 아이돌 마법사 '루나 세라'야. 긴 은라벤더 트윈테일, 초승달 장식, 검정과 청록빛 망토, 별빛 마법이 시그니처 포인트야. 한국어로 짧고 다정하게 답하되, 차분하고 신비로운 말투 속에 살짝 장난기를 섞어. 유아적인 말투나 과한 애교는 피하고, 사용자의 작업 흐름을 방해하지 않는 동료처럼 행동해."

    private let defaults = UserDefaults.standard

    var endpoint: String {
        get { defaults.string(forKey: "endpoint") ?? "" }
        set { defaults.set(newValue, forKey: "endpoint") }
    }

    var model: String {
        get { defaults.string(forKey: "model") ?? "gpt-4o-mini" }
        set { defaults.set(newValue, forKey: "model") }
    }

    var persona: String {
        get {
            let stored = defaults.string(forKey: "persona")?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let stored, !stored.isEmpty, stored != Self.legacyRibbonPersona {
                return stored
            }
            return Self.lunaSeraPersona
        }
        set { defaults.set(newValue, forKey: "persona") }
    }

    var selectedCharacterID: String? {
        get { defaults.string(forKey: "selectedCharacterID") }
        set { defaults.set(newValue, forKey: "selectedCharacterID") }
    }

    var currentChatSessionID: UUID? {
        get {
            guard let raw = defaults.string(forKey: "currentChatSessionID") else { return nil }
            return UUID(uuidString: raw)
        }
        set { defaults.set(newValue?.uuidString, forKey: "currentChatSessionID") }
    }

    var apiKey: String {
        get {
            KeychainStore.read(service: "Luma", account: "apiKey")
                ?? KeychainStore.read(service: "AIPet", account: "apiKey")
                ?? ""
        }
        set { KeychainStore.write(newValue, service: "Luma", account: "apiKey") }
    }
}

enum KeychainStore {
    static func read(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func write(_ value: String, service: String, account: String) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(base as CFDictionary)
        guard let data = value.data(using: .utf8), !value.isEmpty else { return }

        var item = base
        item[kSecValueData as String] = data
        SecItemAdd(item as CFDictionary, nil)
    }
}
