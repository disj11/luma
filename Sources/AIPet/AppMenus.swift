import AppKit

enum AppMenus {
    static func installMainMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "Luma 종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "편집")
        editMenu.addItem(NSMenuItem(title: "실행 취소", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "다시 실행", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: "오려두기", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "복사", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "붙여넣기", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "전체 선택", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "윈도우")
        windowMenu.addItem(NSMenuItem(title: "창 닫기", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        windowItem.submenu = windowMenu
        mainMenu.addItem(windowItem)

        NSApp.mainMenu = mainMenu
    }
}

final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(runHandler), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func runHandler() {
        handler()
    }
}

final class RoundedPanelView: NSView {
    var fillColor = NSColor.controlBackgroundColor
    var strokeColor = NSColor.separatorColor.withAlphaComponent(0.35)
    var cornerRadius: CGFloat = 14

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        fillColor.setFill()
        strokeColor.setStroke()
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: cornerRadius, yRadius: cornerRadius)
        path.fill()
        path.stroke()
    }
}

final class ModernTextField: NSTextField {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isBordered = true
        isBezeled = true
        bezelStyle = .roundedBezel
        drawsBackground = true
        backgroundColor = .textBackgroundColor
        focusRingType = .none
        font = .systemFont(ofSize: 13)
        lineBreakMode = .byTruncatingMiddle
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class ModernSecureTextField: NSSecureTextField {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isBordered = true
        isBezeled = true
        bezelStyle = .roundedBezel
        drawsBackground = true
        backgroundColor = .textBackgroundColor
        focusRingType = .none
        font = .systemFont(ofSize: 13)
        lineBreakMode = .byTruncatingMiddle
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
