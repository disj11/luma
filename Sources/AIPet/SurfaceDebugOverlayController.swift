import AppKit

final class SurfaceDebugOverlayController {
    private let world: WorldModel
    private var windows: [NSWindow] = []
    private var timer: Timer?

    var isVisible: Bool {
        !windows.isEmpty
    }

    init(world: WorldModel) {
        self.world = world
    }

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        hide()
        windows = NSScreen.screens.map { screen in
            let view = SurfaceDebugOverlayView(frame: CGRect(origin: .zero, size: screen.frame.size))
            view.screenOrigin = screen.frame.origin
            view.surfaces = world.surfaces

            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.backgroundColor = .clear
            window.isOpaque = false
            window.ignoresMouseEvents = true
            window.hasShadow = false
            window.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue - 1)
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.contentView = view
            window.orderFrontRegardless()
            return window
        }

        timer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func hide() {
        timer?.invalidate()
        timer = nil
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
    }

    private func refresh() {
        world.refreshIfNeeded()
        for window in windows {
            guard let view = window.contentView as? SurfaceDebugOverlayView else { continue }
            view.surfaces = world.surfaces
            view.needsDisplay = true
        }
    }
}

private final class SurfaceDebugOverlayView: NSView {
    var screenOrigin = CGPoint.zero
    var surfaces: [Surface] = []

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill()

        for surface in surfaces where frameOnThisScreen(surface.frame).intersects(bounds) {
            draw(surface)
        }
    }

    private func draw(_ surface: Surface) {
        let rect = frameOnThisScreen(surface.frame)
        let color = color(for: surface.kind)
        color.withAlphaComponent(0.22).setFill()
        color.withAlphaComponent(0.86).setStroke()

        let path = NSBezierPath(rect: rect)
        path.lineWidth = surface.kind.isWalkable ? 2.2 : 1.4
        path.fill()
        path.stroke()

        let label = "\(surface.kind.rawValue) \(surface.ownerName ?? "")"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .medium),
            .foregroundColor: color
        ]
        label.draw(
            at: CGPoint(x: rect.minX + 4, y: rect.maxY + 3),
            withAttributes: attributes
        )
    }

    private func frameOnThisScreen(_ globalFrame: CGRect) -> CGRect {
        CGRect(
            x: globalFrame.minX - screenOrigin.x,
            y: globalFrame.minY - screenOrigin.y,
            width: globalFrame.width,
            height: globalFrame.height
        )
    }

    private func color(for kind: SurfaceKind) -> NSColor {
        switch kind {
        case .screenBottom:
            return .systemGreen
        case .dockTop:
            return .systemMint
        case .windowTop:
            return .systemBlue
        case .windowBottom:
            return .systemPink
        case .windowLeftEdge, .windowRightEdge:
            return .systemOrange
        }
    }
}
