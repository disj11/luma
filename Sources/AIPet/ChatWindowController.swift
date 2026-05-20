import AppKit

final class ChatWindowController: NSWindowController {
    var onPetReply: ((String) -> Void)?

    private let settings: SettingsStore
    private let sessionStore = ChatSessionStore()
    private lazy var client = AIClient(settings: settings)
    private let sessionPopup = NSPopUpButton()
    private let newSessionButton = NSButton()
    private let clearSessionButton = NSButton()
    private let messagesStack = NSStackView()
    private let scrollView = NSScrollView()
    private let input = ModernTextField()
    private let sendButton = NSButton()
    private let retryButton = NSButton()
    private var sessions: [ChatSession] = []
    private var currentSession = ChatSession.empty()
    private var isBusy = false
    private var currentRequest: AIRequest?
    private var lastFailedPrompt: String?

    init(settings: SettingsStore) {
        self.settings = settings
        let window = ShortcutWindow(
            contentRect: CGRect(x: 0, y: 0, width: 520, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Luma"
        window.titlebarAppearsTransparent = true
        window.center()
        super.init(window: window)
        loadSessions()
        buildUI()
        renderCurrentSession()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(with prompt: String?) {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        if let prompt {
            input.stringValue = prompt
        }
        scrollToBottom()
        window?.makeFirstResponder(input)
    }

    private func buildUI() {
        guard let contentView = window?.contentView else { return }
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = 14
        root.edgeInsets = NSEdgeInsets(top: 24, left: 18, bottom: 18, right: 18)
        root.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            root.topAnchor.constraint(equalTo: contentView.topAnchor),
            root.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        let header = NSStackView()
        header.orientation = .vertical
        header.spacing = 8
        let title = NSTextField(labelWithString: "Luma")
        title.font = .systemFont(ofSize: 21, weight: .semibold)
        let subtitle = NSTextField(labelWithString: "캐릭터 말투로 이어지는 대화를 나눕니다.")
        subtitle.textColor = .secondaryLabelColor
        subtitle.font = .systemFont(ofSize: 12)
        header.addArrangedSubview(title)
        header.addArrangedSubview(subtitle)

        let sessionBar = NSStackView()
        sessionBar.orientation = .horizontal
        sessionBar.spacing = 8

        sessionPopup.target = self
        sessionPopup.action = #selector(selectSession)
        sessionBar.addArrangedSubview(sessionPopup)

        newSessionButton.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "새 대화")
        newSessionButton.title = ""
        newSessionButton.isBordered = false
        newSessionButton.target = self
        newSessionButton.action = #selector(newSession)
        sessionBar.addArrangedSubview(newSessionButton)

        clearSessionButton.image = NSImage(systemSymbolName: "trash", accessibilityDescription: "대화 비우기")
        clearSessionButton.title = ""
        clearSessionButton.isBordered = false
        clearSessionButton.target = self
        clearSessionButton.action = #selector(clearCurrentSession)
        sessionBar.addArrangedSubview(clearSessionButton)

        header.addArrangedSubview(sessionBar)
        root.addArrangedSubview(header)

        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        messagesStack.orientation = .vertical
        messagesStack.spacing = 10
        messagesStack.edgeInsets = NSEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        messagesStack.translatesAutoresizingMaskIntoConstraints = false

        let document = FlippedDocumentView()
        document.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(messagesStack)
        scrollView.documentView = document

        NSLayoutConstraint.activate([
            document.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            document.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.contentView.heightAnchor),
            messagesStack.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            messagesStack.trailingAnchor.constraint(equalTo: document.trailingAnchor),
            messagesStack.topAnchor.constraint(equalTo: document.topAnchor),
            messagesStack.bottomAnchor.constraint(equalTo: document.bottomAnchor)
        ])

        root.addArrangedSubview(scrollView)

        let composer = RoundedPanelView()
        composer.fillColor = NSColor.controlBackgroundColor.withAlphaComponent(0.9)
        composer.cornerRadius = 16
        composer.translatesAutoresizingMaskIntoConstraints = false
        root.addArrangedSubview(composer)

        let composerStack = NSStackView()
        composerStack.orientation = .horizontal
        composerStack.spacing = 10
        composerStack.edgeInsets = NSEdgeInsets(top: 10, left: 12, bottom: 10, right: 10)
        composerStack.translatesAutoresizingMaskIntoConstraints = false
        composer.addSubview(composerStack)

        input.placeholderString = "무엇을 도와줄까요?"
        input.target = self
        input.action = #selector(send)

        sendButton.image = NSImage(systemSymbolName: "arrow.up.circle.fill", accessibilityDescription: "보내기")
        sendButton.title = ""
        sendButton.isBordered = false
        sendButton.target = self
        sendButton.action = #selector(sendOrCancel)
        sendButton.contentTintColor = .controlAccentColor

        retryButton.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "다시 시도")
        retryButton.title = ""
        retryButton.isBordered = false
        retryButton.target = self
        retryButton.action = #selector(retryLastPrompt)
        retryButton.isHidden = true

        composerStack.addArrangedSubview(input)
        composerStack.addArrangedSubview(retryButton)
        composerStack.addArrangedSubview(sendButton)

        NSLayoutConstraint.activate([
            composerStack.leadingAnchor.constraint(equalTo: composer.leadingAnchor),
            composerStack.trailingAnchor.constraint(equalTo: composer.trailingAnchor),
            composerStack.topAnchor.constraint(equalTo: composer.topAnchor),
            composerStack.bottomAnchor.constraint(equalTo: composer.bottomAnchor),
            composer.heightAnchor.constraint(equalToConstant: 56),
            retryButton.widthAnchor.constraint(equalToConstant: 30),
            sendButton.widthAnchor.constraint(equalToConstant: 34)
        ])
    }

    @objc private func sendOrCancel() {
        if isBusy {
            cancelCurrentRequest()
        } else {
            send()
        }
    }

    @objc private func send() {
        guard !isBusy else { return }
        let text = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        retryButton.isHidden = true
        lastFailedPrompt = nil
        input.stringValue = ""
        sendPrompt(text)
    }

    @objc private func retryLastPrompt() {
        guard !isBusy, let prompt = lastFailedPrompt else { return }
        retryButton.isHidden = true
        lastFailedPrompt = nil
        sendPrompt(prompt)
    }

    private func sendPrompt(_ text: String) {
        appendStoredMessage(ChatMessage(role: "user", content: text))
        setBusy(true)

        currentRequest = client.send(messages: currentSession.messages, summary: currentSession.summary) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.currentRequest = nil
                self.setBusy(false)
                switch result {
                case .success(let reply):
                    self.appendStoredMessage(ChatMessage(role: "assistant", content: reply))
                    self.summarizeCurrentSessionIfNeeded()
                    self.onPetReply?(reply)
                case .failure(let error):
                    guard !self.isCancellation(error) else {
                        self.appendMessage("요청을 취소했어요.", role: .assistant)
                        return
                    }
                    self.lastFailedPrompt = text
                    self.retryButton.isHidden = false
                    let message = "\(error.localizedDescription)\n\n다시 시도할 수 있어요."
                    self.appendStoredMessage(ChatMessage(role: "assistant", content: message))
                    self.onPetReply?(error.localizedDescription)
                }
            }
        }
    }

    private func cancelCurrentRequest() {
        currentRequest?.cancel()
        currentRequest = nil
        setBusy(false)
        appendMessage("요청을 취소했어요.", role: .assistant)
    }

    private func setBusy(_ busy: Bool) {
        isBusy = busy
        input.isEnabled = !busy
        sendButton.image = NSImage(
            systemSymbolName: busy ? "stop.circle.fill" : "arrow.up.circle.fill",
            accessibilityDescription: busy ? "취소" : "보내기"
        )
        sendButton.contentTintColor = busy ? .systemRed : .controlAccentColor
        if busy {
            appendMessage("생각 중...", role: .assistant, transient: true)
        } else {
            removeTransientMessages()
        }
    }

    private func appendMessage(_ text: String, role: ChatRole, transient: Bool = false) {
        removeTransientMessages()

        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 8
        row.identifier = transient ? NSUserInterfaceItemIdentifier("transient") : nil

        if role == .user {
            row.addArrangedSubview(NSView())
        }

        let bubble = MessageBubbleView(text: text, role: role)
        bubble.widthAnchor.constraint(lessThanOrEqualToConstant: 340).isActive = true
        row.addArrangedSubview(bubble)

        if role == .assistant {
            row.addArrangedSubview(NSView())
        }

        messagesStack.addArrangedSubview(row)
        messagesStack.layoutSubtreeIfNeeded()
        scrollView.documentView?.layoutSubtreeIfNeeded()
        scrollToBottom()
    }

    private func appendStoredMessage(_ message: ChatMessage) {
        removeTransientMessages()
        currentSession.messages.append(message)
        currentSession.updatedAt = Date()
        if currentSession.title == "새 대화", message.role == "user" {
            currentSession.title = String(message.content.prefix(24))
        }
        saveCurrentSession()
        reloadSessionPopup()
        appendMessage(message.content, role: ChatRole(message.role))
    }

    private func removeTransientMessages() {
        messagesStack.arrangedSubviews
            .filter { $0.identifier?.rawValue == "transient" }
            .forEach { view in
                messagesStack.removeArrangedSubview(view)
                view.removeFromSuperview()
            }
    }

    private func loadSessions() {
        sessions = sessionStore.loadSessions()
        if let currentID = settings.currentChatSessionID,
           let session = sessions.first(where: { $0.id == currentID }) {
            currentSession = session
        } else if let latest = sessions.first {
            currentSession = latest
            settings.currentChatSessionID = latest.id
        } else {
            currentSession = ChatSession.empty()
            saveCurrentSession()
        }
    }

    private func saveCurrentSession() {
        sessionStore.save(currentSession)
        settings.currentChatSessionID = currentSession.id
        sessions.removeAll { $0.id == currentSession.id }
        sessions.insert(currentSession, at: 0)
    }

    private func reloadSessionPopup() {
        sessionPopup.removeAllItems()
        for session in sessions.sorted(by: { $0.updatedAt > $1.updatedAt }) {
            sessionPopup.addItem(withTitle: session.title)
            sessionPopup.lastItem?.representedObject = session.id
        }
        if let index = sessionPopup.itemArray.firstIndex(where: { ($0.representedObject as? UUID) == currentSession.id }) {
            sessionPopup.selectItem(at: index)
        }
    }

    private func renderCurrentSession() {
        messagesStack.arrangedSubviews.forEach { view in
            messagesStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        reloadSessionPopup()
        for message in currentSession.messages {
            appendMessage(message.content, role: ChatRole(message.role))
        }
    }

    @objc private func selectSession() {
        guard let id = sessionPopup.selectedItem?.representedObject as? UUID,
              let session = sessions.first(where: { $0.id == id }) else { return }
        currentSession = session
        settings.currentChatSessionID = session.id
        renderCurrentSession()
    }

    @objc private func newSession() {
        currentSession = ChatSession.empty()
        saveCurrentSession()
        renderCurrentSession()
        window?.makeFirstResponder(input)
    }

    @objc private func clearCurrentSession() {
        currentSession.messages.removeAll()
        currentSession.summary = ""
        currentSession.updatedAt = Date()
        currentSession.title = "새 대화"
        lastFailedPrompt = nil
        retryButton.isHidden = true
        saveCurrentSession()
        renderCurrentSession()
    }

    private func summarizeCurrentSessionIfNeeded() {
        let maxMessages = 30
        let keepMessages = 20
        guard currentSession.messages.count > maxMessages else { return }

        let archived = currentSession.messages.prefix(currentSession.messages.count - keepMessages)
        let newSummary = archived.map { message in
            let speaker = message.role == "user" ? "사용자" : "루마"
            let compact = message.content
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(120)
            return "- \(speaker): \(compact)"
        }.joined(separator: "\n")

        let previous = currentSession.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        currentSession.summary = ([previous, newSummary].filter { !$0.isEmpty }).joined(separator: "\n")
        currentSession.messages = Array(currentSession.messages.suffix(keepMessages))
        saveCurrentSession()
        renderCurrentSession()
    }

    private func isCancellation(_ error: Error) -> Bool {
        (error as NSError).domain == NSURLErrorDomain && (error as NSError).code == NSURLErrorCancelled
    }

    private func scrollToBottom() {
        guard let documentView = scrollView.documentView else { return }
        let visibleHeight = scrollView.contentView.bounds.height
        let targetY = max(0, documentView.bounds.height - visibleHeight)
        scrollView.contentView.scroll(to: CGPoint(x: 0, y: targetY))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }
}

private final class FlippedDocumentView: NSView {
    override var isFlipped: Bool { true }
}

private enum ChatRole {
    case user
    case assistant

    init(_ role: String) {
        self = role == "user" ? .user : .assistant
    }
}

private final class MessageBubbleView: NSView {
    private let text: String
    private let role: ChatRole
    private let label = NSTextField(wrappingLabelWithString: "")

    init(text: String, role: ChatRole) {
        self.text = text
        self.role = role
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }

    private func setup() {
        wantsLayer = true
        label.font = .systemFont(ofSize: 13)
        label.textColor = role == .user ? .white : .labelColor
        label.attributedStringValue = renderedText()
        label.allowsEditingTextAttributes = true
        label.isSelectable = true
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10)
        ])
    }

    private func renderedText() -> NSAttributedString {
        guard role == .assistant,
              let attributed = try? AttributedString(markdown: text) else {
            return NSAttributedString(string: text, attributes: [
                .font: NSFont.systemFont(ofSize: 13),
                .foregroundColor: role == .user ? NSColor.white : NSColor.labelColor
            ])
        }

        let mutable = NSMutableAttributedString(attributed)
        let fullRange = NSRange(location: 0, length: mutable.length)
        mutable.addAttribute(.foregroundColor, value: NSColor.labelColor, range: fullRange)
        mutable.enumerateAttribute(.font, in: fullRange) { value, range, _ in
            guard value == nil else { return }
            mutable.addAttribute(.font, value: NSFont.systemFont(ofSize: 13), range: range)
        }
        return mutable
    }

    override func layout() {
        super.layout()
        layer?.cornerRadius = 16
        layer?.masksToBounds = true
        layer?.backgroundColor = (role == .user
            ? NSColor.controlAccentColor
            : NSColor.controlBackgroundColor).cgColor
    }
}
