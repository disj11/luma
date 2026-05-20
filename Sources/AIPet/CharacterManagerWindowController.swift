import AppKit

final class CharacterManagerWindowController: NSWindowController {
    var onSelectPack: ((LoadedCharacterPack) -> Void)?

    private let library: CharacterPackLibrary
    private var packs: [LoadedCharacterPack] = []
    private let popup = NSPopUpButton()
    private let posePopup = NSPopUpButton()
    private let previewView = CharacterPosePreviewView(frame: CGRect(x: 0, y: 0, width: 260, height: 300))
    private let detailLabel = NSTextField(labelWithString: "")
    private let directoryLabel = NSTextField(labelWithString: "")

    init(library: CharacterPackLibrary) {
        self.library = library
        let window = ShortcutWindow(
            contentRect: CGRect(x: 0, y: 0, width: 680, height: 420),
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

        let root = NSStackView()
        root.orientation = .horizontal
        root.spacing = 22
        root.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        root.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            root.topAnchor.constraint(equalTo: contentView.topAnchor),
            root.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 14
        root.addArrangedSubview(stack)

        let title = NSTextField(labelWithString: "캐릭터 선택")
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        stack.addArrangedSubview(title)

        popup.target = self
        popup.action = #selector(selectCharacter)
        stack.addArrangedSubview(popup)

        let poseTitle = NSTextField(labelWithString: "포즈 미리보기")
        poseTitle.font = .systemFont(ofSize: 13, weight: .semibold)
        stack.addArrangedSubview(poseTitle)

        posePopup.target = self
        posePopup.action = #selector(selectPose)
        stack.addArrangedSubview(posePopup)

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
        let validateButton = NSButton(title: "팩 검증...", target: self, action: #selector(validateCharacter))
        validateButton.bezelStyle = .rounded
        let revealButton = NSButton(title: "캐릭터 폴더 열기", target: self, action: #selector(openCharactersFolder))
        revealButton.bezelStyle = .rounded

        buttons.addArrangedSubview(addButton)
        buttons.addArrangedSubview(validateButton)
        buttons.addArrangedSubview(revealButton)
        buttons.addArrangedSubview(NSView())
        stack.addArrangedSubview(buttons)

        let spacer = NSView()
        stack.addArrangedSubview(spacer)

        previewView.translatesAutoresizingMaskIntoConstraints = false
        root.addArrangedSubview(previewView)
        NSLayoutConstraint.activate([
            stack.widthAnchor.constraint(greaterThanOrEqualToConstant: 360),
            previewView.widthAnchor.constraint(equalToConstant: 260)
        ])
    }

    @objc private func selectCharacter() {
        let index = popup.indexOfSelectedItem
        guard packs.indices.contains(index) else { return }
        let pack = packs[index]
        library.select(pack)
        onSelectPack?(pack)
        updateDetails()
    }

    @objc private func selectPose() {
        updatePreview()
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

    @objc private func validateCharacter() {
        let panel = NSOpenPanel()
        panel.title = "검증할 캐릭터 팩 폴더 선택"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "검증"

        panel.beginSheetModal(for: window!) { [weak self] response in
            guard let self, response == .OK, let url = panel.url else { return }
            let report = CharacterPackValidator.validate(folder: url)
            self.showValidationReport(report)
        }
    }

    private func updateDetails() {
        let index = popup.indexOfSelectedItem
        guard packs.indices.contains(index) else {
            detailLabel.stringValue = "사용 가능한 캐릭터 팩이 없습니다."
            directoryLabel.stringValue = library.userCharactersDirectory.path
            posePopup.removeAllItems()
            previewView.pack = nil
            return
        }

        let pack = packs[index]
        let source = pack.isBundled ? "기본 제공" : "사용자 추가"
        detailLabel.stringValue = "\(pack.manifest.displayName) · \(source) · \(pack.manifest.id)"
        directoryLabel.stringValue = pack.baseURL.path
        reloadPoses(for: pack)
        updatePreview()
    }

    private func reloadPoses(for pack: LoadedCharacterPack) {
        let selectedPose = selectedPoseKey()
        posePopup.removeAllItems()
        for pose in PoseKey.allCases where pack.images[pose] != nil {
            posePopup.addItem(withTitle: pose.rawValue)
        }

        if let selectedPose, pack.images[selectedPose] != nil {
            posePopup.selectItem(withTitle: selectedPose.rawValue)
        } else if let defaultItem = posePopup.item(withTitle: pack.manifest.defaultPose.rawValue) {
            posePopup.select(defaultItem)
        } else {
            posePopup.selectItem(at: 0)
        }
    }

    private func selectedPoseKey() -> PoseKey? {
        PoseKey(rawValue: posePopup.titleOfSelectedItem ?? "")
    }

    private func updatePreview() {
        let index = popup.indexOfSelectedItem
        guard packs.indices.contains(index), let pose = selectedPoseKey() else {
            previewView.pack = nil
            return
        }

        previewView.pack = packs[index]
        previewView.pose = pose
    }

    private func showError(_ error: Error) {
        let alert = NSAlert(error: error)
        alert.beginSheetModal(for: window!)
    }

    private func showValidationReport(_ report: CharacterPackValidationReport) {
        let alert = NSAlert()
        alert.messageText = report.isValid ? "캐릭터 팩을 사용할 수 있습니다." : "캐릭터 팩에 문제가 있습니다."
        alert.informativeText = report.summary
        alert.alertStyle = report.isValid ? .informational : .warning
        alert.addButton(withTitle: "확인")
        alert.beginSheetModal(for: window!)
    }
}

private final class CharacterPosePreviewView: NSView {
    var pack: LoadedCharacterPack? {
        didSet { needsDisplay = true }
    }

    var pose: PoseKey = .idle {
        didSet { needsDisplay = true }
    }

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let panelRect = bounds.insetBy(dx: 2, dy: 2)
        NSColor.controlBackgroundColor.withAlphaComponent(0.72).setFill()
        NSBezierPath(roundedRect: panelRect, xRadius: 12, yRadius: 12).fill()

        guard let pack, let image = pack.images[pose] else {
            drawCentered("미리볼 포즈가 없습니다.", in: panelRect)
            return
        }

        let windowSize = CGSize(width: 220, height: 220)
        let previewOrigin = CGPoint(x: panelRect.midX - windowSize.width / 2, y: panelRect.maxY - windowSize.height - 26)
        let previewRect = CGRect(origin: previewOrigin, size: windowSize)

        drawPreviewBackground(previewRect)

        if let target = pack.renderedImageRect(for: pose, windowSize: windowSize) {
            let imageRect = target.offsetBy(dx: previewRect.minX, dy: previewRect.minY)
            image.draw(
                in: imageRect,
                from: CGRect(origin: .zero, size: image.size),
                operation: .sourceOver,
                fraction: 1,
                respectFlipped: true,
                hints: [.interpolation: NSImageInterpolation.high.rawValue]
            )

            NSColor.systemBlue.withAlphaComponent(0.65).setStroke()
            let imagePath = NSBezierPath(rect: imageRect)
            imagePath.lineWidth = 1
            imagePath.stroke()
        }

        if let visibleBounds = pack.visibleBoundsInPetWindow(for: pose, windowSize: windowSize) {
            let boundsRect = visibleBounds.offsetBy(dx: previewRect.minX, dy: previewRect.minY)
            NSColor.systemPurple.withAlphaComponent(0.82).setStroke()
            let boundsPath = NSBezierPath(rect: boundsRect)
            boundsPath.lineWidth = 1.5
            boundsPath.stroke()

            NSColor.systemRed.withAlphaComponent(0.9).setStroke()
            let baseline = NSBezierPath()
            baseline.move(to: CGPoint(x: previewRect.minX, y: boundsRect.minY))
            baseline.line(to: CGPoint(x: previewRect.maxX, y: boundsRect.minY))
            baseline.lineWidth = 1.3
            baseline.stroke()

            let metrics = "하단 기준 \(Int(visibleBounds.minY.rounded()))px · 영역 \(Int(visibleBounds.width))x\(Int(visibleBounds.height))"
            drawCaption(metrics, at: CGPoint(x: panelRect.minX + 14, y: panelRect.minY + 38))
        }

        drawCaption("\(pack.manifest.displayName) · \(pose.rawValue)", at: CGPoint(x: panelRect.minX + 14, y: panelRect.minY + 16))
    }

    private func drawPreviewBackground(_ rect: CGRect) {
        NSColor.windowBackgroundColor.setFill()
        NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8).fill()

        NSColor.separatorColor.withAlphaComponent(0.5).setStroke()
        let border = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
        border.lineWidth = 1
        border.stroke()

        NSColor.separatorColor.withAlphaComponent(0.4).setStroke()
        let ground = NSBezierPath()
        ground.move(to: CGPoint(x: rect.minX + 10, y: rect.minY + 20))
        ground.line(to: CGPoint(x: rect.maxX - 10, y: rect.minY + 20))
        ground.lineWidth = 1
        ground.stroke()
    }

    private func drawCentered(_ text: String, in rect: CGRect) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let size = text.size(withAttributes: attributes)
        text.draw(at: CGPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2), withAttributes: attributes)
    }

    private func drawCaption(_ text: String, at point: CGPoint) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        text.draw(at: point, withAttributes: attributes)
    }
}
