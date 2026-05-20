import AppKit

final class SettingsWindowController: NSWindowController {
    private let settings: SettingsStore
    private let endpointField = NSTextField()
    private let modelField = NSTextField()
    private let apiKeyField = NSSecureTextField()
    private let searchEndpointField = NSTextField()
    private let searchApiKeyField = NSSecureTextField()
    private let personaField = NSTextView()

    init(settings: SettingsStore) {
        self.settings = settings

        let window = ShortcutWindow(
            contentRect: CGRect(x: 0, y: 0, width: 640, height: 640),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "설정"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildUI()
        loadValues()
        placeWindowOnVisibleScreen()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        placeWindowOnVisibleScreen()
        super.showWindow(sender)
    }

    private func buildUI() {
        guard let contentView = window?.contentView else { return }

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 16
        root.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 20, right: 24)
        root.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            root.topAnchor.constraint(equalTo: contentView.topAnchor),
            root.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        let title = NSTextField(labelWithString: "AI 연결 설정")
        title.font = .systemFont(ofSize: 21, weight: .semibold)
        root.addArrangedSubview(title)

        let description = NSTextField(wrappingLabelWithString: "사용할 AI API, 선택 검색 provider, 페르소나를 설정합니다. 기본 데스크톱 동작은 Accessibility 권한을 요구하지 않습니다.")
        description.textColor = .secondaryLabelColor
        description.font = .systemFont(ofSize: 13)
        root.addArrangedSubview(description)
        description.widthAnchor.constraint(equalToConstant: 580).isActive = true

        root.addArrangedSubview(row(title: "API 엔드포인트", subtitle: "예: https://api.openai.com", field: endpointField))
        root.addArrangedSubview(row(title: "모델", subtitle: "요청에 사용할 모델 이름입니다.", field: modelField))
        root.addArrangedSubview(row(title: "API 키", subtitle: "Keychain에 저장됩니다.", field: apiKeyField))
        root.addArrangedSubview(row(title: "검색 엔드포인트", subtitle: "선택 사항입니다. GET 요청에 q 파라미터를 붙여 JSON 검색 결과를 가져옵니다.", field: searchEndpointField))
        root.addArrangedSubview(row(title: "검색 API 키", subtitle: "선택 사항입니다. Bearer 토큰으로 전송됩니다.", field: searchApiKeyField))

        let personaLabel = NSTextField(labelWithString: "페르소나")
        personaLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        root.addArrangedSubview(personaLabel)

        let scroll = NSScrollView()
        scroll.borderType = .bezelBorder
        scroll.hasVerticalScroller = true
        scroll.documentView = personaField
        personaField.font = .systemFont(ofSize: 13)
        personaField.textContainerInset = CGSize(width: 8, height: 8)
        root.addArrangedSubview(scroll)

        NSLayoutConstraint.activate([
            scroll.widthAnchor.constraint(equalToConstant: 580),
            scroll.heightAnchor.constraint(equalToConstant: 140)
        ])

        let hint = NSTextField(wrappingLabelWithString: "AI 엔드포인트가 /chat/completions로 끝나지 않으면 /v1/chat/completions를 자동으로 붙입니다. 검색 엔드포인트는 GET 요청에 q 파라미터를 붙여 호출합니다.")
        hint.textColor = .tertiaryLabelColor
        hint.font = .systemFont(ofSize: 12)
        root.addArrangedSubview(hint)
        hint.widthAnchor.constraint(equalToConstant: 580).isActive = true

        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.spacing = 10
        buttons.widthAnchor.constraint(equalToConstant: 580).isActive = true
        buttons.addArrangedSubview(NSView())

        let saveButton = NSButton(title: "저장", target: self, action: #selector(save))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        buttons.addArrangedSubview(saveButton)
        root.addArrangedSubview(buttons)
    }

    private func row(title: String, subtitle: String, field: NSTextField) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6

        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        stack.addArrangedSubview(label)

        configureInput(field, placeholder: title)
        stack.addArrangedSubview(field)

        let note = NSTextField(labelWithString: subtitle)
        note.textColor = .tertiaryLabelColor
        note.font = .systemFont(ofSize: 11)
        stack.addArrangedSubview(note)
        return stack
    }

    private func configureInput(_ field: NSTextField, placeholder: String) {
        field.placeholderString = placeholder
        field.isBordered = true
        field.isBezeled = true
        field.bezelStyle = .roundedBezel
        field.drawsBackground = true
        field.backgroundColor = .textBackgroundColor
        field.focusRingType = .default
        field.font = .systemFont(ofSize: 13)
        field.lineBreakMode = .byTruncatingMiddle
        NSLayoutConstraint.activate([
            field.widthAnchor.constraint(equalToConstant: 580),
            field.heightAnchor.constraint(equalToConstant: 30)
        ])
    }

    private func placeWindowOnVisibleScreen() {
        guard let window else { return }
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSScreen.screens.first?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1200, height: 800)
        let size = window.frame.size
        let origin = CGPoint(
            x: visibleFrame.midX - size.width / 2,
            y: visibleFrame.midY - size.height / 2
        )
        window.setFrame(CGRect(origin: origin, size: size), display: false)
    }

    private func loadValues() {
        endpointField.stringValue = settings.endpoint
        modelField.stringValue = settings.model
        apiKeyField.stringValue = settings.apiKey
        searchEndpointField.stringValue = settings.searchEndpoint
        searchApiKeyField.stringValue = settings.searchApiKey
        personaField.string = settings.persona
    }

    @objc private func save() {
        settings.endpoint = endpointField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.model = modelField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.apiKey = apiKeyField.stringValue
        settings.searchEndpoint = searchEndpointField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.searchApiKey = searchApiKeyField.stringValue
        settings.persona = personaField.string.trimmingCharacters(in: .whitespacesAndNewlines)
        window?.close()
    }
}
