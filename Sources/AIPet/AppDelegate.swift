import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var visibilityMenuItem: NSMenuItem?
    private var petController: PetController?
    private var settingsController: SettingsWindowController?
    private var chatController: ChatWindowController?
    private var characterController: CharacterManagerWindowController?
    private var onboardingController: OnboardingWindowController?
    private var characterLibrary: CharacterPackLibrary?
    private var surfaceDebugOverlay: SurfaceDebugOverlayController?
    private let globalHotKey = GlobalHotKey()

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppMenus.installMainMenu()

        let settings = SettingsStore()
        let characterLibrary = CharacterPackLibrary(settings: settings)
        let world = WorldModel()
        let petController = PetController(world: world, characterPack: characterLibrary.selectedPack())
        let chatController = ChatWindowController(settings: settings)

        petController.onOpenChat = { [weak chatController] prompt in
            chatController?.show(with: prompt)
        }
        petController.onOpenSettings = { [weak self] in
            self?.openSettings()
        }
        petController.onOpenCharacters = { [weak self] in
            self?.openCharacters()
        }
        petController.onQuit = {
            NSApp.terminate(nil)
        }
        chatController.onPetReply = { [weak petController] reply in
            petController?.speak(reply)
        }

        self.petController = petController
        self.chatController = chatController
        self.characterLibrary = characterLibrary
        self.surfaceDebugOverlay = SurfaceDebugOverlayController(world: world)

        installNotificationHandlers()
        configureStatusItem()
        globalHotKey.registerOptionShiftSpace { [weak self] in
            self?.openChat()
        }
        petController.start()
        showOnboardingIfNeeded(settings: settings)
    }

    private func installNotificationHandlers() {
        NotificationCenter.default.addObserver(self, selector: #selector(openChat), name: .aiPetOpenChat, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(openSettings), name: .aiPetOpenSettings, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(openCharacters), name: .aiPetOpenCharacters, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(quit), name: .aiPetQuit, object: nil)
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Luma")

        let menu = NSMenu()
        menu.delegate = self

        let visibilityItem = statusMenuItem(title: "캐릭터 숨기기", action: #selector(togglePetVisibility))
        visibilityMenuItem = visibilityItem
        menu.addItem(visibilityItem)
        menu.addItem(statusMenuItem(title: "대화하기 (⌥⇧Space)", action: #selector(openChat)))
        menu.addItem(.separator())
        menu.addItem(statusMenuItem(title: "캐릭터", action: #selector(openCharacters)))
        menu.addItem(statusMenuItem(title: "설정", action: #selector(openSettings)))
        menu.addItem(.separator())
        menu.addItem(statusMenuItem(title: "디버그 Surface", action: #selector(toggleSurfaceDebugOverlay)))
        menu.addItem(.separator())
        menu.addItem(statusMenuItem(title: "종료", action: #selector(quit)))
        item.menu = menu
        statusItem = item
    }

    private func statusMenuItem(title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func togglePetVisibility() {
        petController?.toggleVisibility()
        updateVisibilityMenuItem()
    }

    @objc private func openChat() {
        chatController?.show(with: nil)
    }

    @objc private func openSettings() {
        settingsController = SettingsWindowController(settings: SettingsStore())
        NSApp.activate(ignoringOtherApps: true)
        settingsController?.showWindow(nil)
        settingsController?.window?.makeKeyAndOrderFront(nil)
        settingsController?.window?.orderFrontRegardless()
    }

    private func showOnboardingIfNeeded(settings: SettingsStore) {
        guard !settings.didShowOnboarding else { return }
        let controller = OnboardingWindowController(settings: settings)
        controller.onOpenSettings = { [weak self] in
            self?.openSettings()
        }
        onboardingController = controller
        NSApp.activate(ignoringOtherApps: true)
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
    }

    @objc private func openCharacters() {
        guard let characterLibrary else { return }
        if characterController == nil {
            let controller = CharacterManagerWindowController(library: characterLibrary)
            controller.onSelectPack = { [weak self] pack in
                self?.characterLibrary?.select(pack)
                self?.petController?.setCharacterPack(pack)
            }
            characterController = controller
        }
        characterController?.reload()
        characterController?.showWindow(nil)
        characterController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func toggleSurfaceDebugOverlay() {
        surfaceDebugOverlay?.toggle()
    }

    private func updateVisibilityMenuItem() {
        visibilityMenuItem?.title = petController?.isVisible == true ? "캐릭터 숨기기" : "캐릭터 부르기"
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        updateVisibilityMenuItem()
    }
}
