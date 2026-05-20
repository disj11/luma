import AppKit

final class PetContextMenuTarget: NSObject {
    @objc func openChat() {
        NotificationCenter.default.post(name: .aiPetOpenChat, object: nil)
    }

    @objc func openSettings() {
        NotificationCenter.default.post(name: .aiPetOpenSettings, object: nil)
    }

    @objc func openCharacters() {
        NotificationCenter.default.post(name: .aiPetOpenCharacters, object: nil)
    }

    @objc func quit() {
        NotificationCenter.default.post(name: .aiPetQuit, object: nil)
    }
}
