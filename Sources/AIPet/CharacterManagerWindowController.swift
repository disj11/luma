import AppKit

final class CharacterManagerWindowController: NSWindowController {
    var onSelectPack: ((LoadedCharacterPack) -> Void)?

    private let library: CharacterPackLibrary
    private var packs: [LoadedCharacterPack] = []
    private let popup = NSPopUpButton()
    private let detailLabel = NSTextField(labelWithString: "")
    private let directoryLabel = NSTextField(labelWithString: "")

    init(library: CharacterPackLibrary) {
        self.library = library
        let window = ShortcutWindow(
            contentRect: CGRect(x: 0, y: 0, width: 520, height: 250),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "캐릭터"
        window.center()
        super.init(window: window)
        buildUI()
        reload()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func reload() {
        packs = library.availablePacks()
        popup.removeAllItems()
        for pack in packs {
            popup.addItem(withTitle: pack.manifest.displayName)
        }

        if let selected = library.selectedPack(),
           let index = packs.firstIndex(where: { $0.manifest.id == selected.manifest.id }) {
            popup.selectItem(at: index)
        } else if !packs.isEmpty {
            popup.selectItem(at: 0)
        }
        updateDetails()
    }

    private func buildUI() {
        guard let contentView = window?.contentView else { return }

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        let title = NSTextField(labelWithString: "캐릭터 선택")
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        stack.addArrangedSubview(title)

        popup.target = self
        popup.action = #selector(selectCharacter)
        stack.addArrangedSubview(popup)

        detailLabel.textColor = .secondaryLabelColor
        detailLabel.lineBreakMode = .byWordWrapping
        detailLabel.maximumNumberOfLines = 3
        stack.addArrangedSubview(detailLabel)

        directoryLabel.textColor = .tertiaryLabelColor
        directoryLabel.font = .systemFont(ofSize: 11)
        directoryLabel.lineBreakMode = .byTruncatingMiddle
        stack.addArrangedSubview(directoryLabel)

        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.spacing = 10

        let addButton = NSButton(title: "캐릭터 추가...", target: self, action: #selector(addCharacter))
        addButton.bezelStyle = .rounded
        let revealButton = NSButton(title: "캐릭터 폴더 열기", target: self, action: #selector(openCharactersFolder))
        revealButton.bezelStyle = .rounded

        buttons.addArrangedSubview(addButton)
        buttons.addArrangedSubview(revealButton)
        buttons.addArrangedSubview(NSView())
        stack.addArrangedSubview(buttons)
    }

    @objc private func selectCharacter() {
        let index = popup.indexOfSelectedItem
        guard packs.indices.contains(index) else { return }
        let pack = packs[index]
        library.select(pack)
        onSelectPack?(pack)
        updateDetails()
    }

    @objc private func addCharacter() {
        let panel = NSOpenPanel()
        panel.title = "캐릭터 팩 폴더 선택"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "추가"

        panel.beginSheetModal(for: window!) { [weak self] response in
            guard let self, response == .OK, let url = panel.url else { return }
            do {
                let pack = try self.library.importPack(from: url)
                self.reload()
                self.onSelectPack?(pack)
            } catch {
                self.showError(error)
            }
        }
    }

    @objc private func openCharactersFolder() {
        try? FileManager.default.createDirectory(at: library.userCharactersDirectory, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([library.userCharactersDirectory])
    }

    private func updateDetails() {
        let index = popup.indexOfSelectedItem
        guard packs.indices.contains(index) else {
            detailLabel.stringValue = "사용 가능한 캐릭터 팩이 없습니다."
            directoryLabel.stringValue = library.userCharactersDirectory.path
            return
        }

        let pack = packs[index]
        let source = pack.isBundled ? "기본 제공" : "사용자 추가"
        detailLabel.stringValue = "\(pack.manifest.displayName) · \(source) · \(pack.manifest.id)"
        directoryLabel.stringValue = pack.baseURL.path
    }

    private func showError(_ error: Error) {
        let alert = NSAlert(error: error)
        alert.beginSheetModal(for: window!)
    }
}
