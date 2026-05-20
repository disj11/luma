import AppKit

final class OnboardingWindowController: NSWindowController {
    var onOpenSettings: (() -> Void)?
    private let settings: SettingsStore

    init(settings: SettingsStore) {
        self.settings = settings
        let window = ShortcutWindow(
            contentRect: CGRect(x: 0, y: 0, width: 520, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Luma 시작하기"
        window.center()
        super.init(window: window)
        buildUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildUI() {
        guard let contentView = window?.contentView else { return }

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 16
        root.edgeInsets = NSEdgeInsets(top: 26, left: 26, bottom: 22, right: 26)
        root.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            root.topAnchor.constraint(equalTo: contentView.topAnchor),
            root.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        let title = NSTextField(labelWithString: "루나가 화면 위에서 도와드릴게요")
        title.font = .systemFont(ofSize: 22, weight: .semibold)
        root.addArrangedSubview(title)

        let subtitle = NSTextField(wrappingLabelWithString: "Luma는 기본 동작에 Accessibility 권한을 요구하지 않습니다. AI와 검색 기능은 사용자가 설정한 API로만 연결됩니다.")
        subtitle.textColor = .secondaryLabelColor
        subtitle.font = .systemFont(ofSize: 13)
        root.addArrangedSubview(subtitle)
        subtitle.widthAnchor.constraint(equalToConstant: 460).isActive = true

        root.addArrangedSubview(feature("대화", "캐릭터를 클릭하거나 ⌥⇧Space로 채팅을 엽니다."))
        root.addArrangedSubview(feature("검색", "설정에서 검색 엔드포인트를 넣으면 최신 정보 요청에 검색 결과를 참고합니다."))
        root.addArrangedSubview(feature("캐릭터", "캐릭터 메뉴에서 팩을 추가하고 포즈 기준선을 미리볼 수 있습니다."))
        root.addArrangedSubview(feature("데이터", "대화 세션은 ~/Library/Application Support/Luma 안에 저장됩니다."))

        root.addArrangedSubview(NSView())

        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.spacing = 10
        buttons.widthAnchor.constraint(equalToConstant: 460).isActive = true
        buttons.addArrangedSubview(NSView())

        let settingsButton = NSButton(title: "설정 열기", target: self, action: #selector(openSettings))
        settingsButton.bezelStyle = .rounded
        buttons.addArrangedSubview(settingsButton)

        let doneButton = NSButton(title: "시작하기", target: self, action: #selector(closeOnboarding))
        doneButton.bezelStyle = .rounded
        doneButton.keyEquivalent = "\r"
        buttons.addArrangedSubview(doneButton)
        root.addArrangedSubview(buttons)
    }

    private func feature(_ title: String, _ body: String) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        stack.addArrangedSubview(titleLabel)

        let bodyLabel = NSTextField(wrappingLabelWithString: body)
        bodyLabel.textColor = .secondaryLabelColor
        bodyLabel.font = .systemFont(ofSize: 12)
        stack.addArrangedSubview(bodyLabel)
        bodyLabel.widthAnchor.constraint(equalToConstant: 460).isActive = true
        return stack
    }

    @objc private func openSettings() {
        settings.didShowOnboarding = true
        close()
        onOpenSettings?()
    }

    @objc private func closeOnboarding() {
        settings.didShowOnboarding = true
        close()
    }
}
