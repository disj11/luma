import AppKit

final class PetController {
    var onOpenChat: ((String?) -> Void)?
    var onOpenSettings: (() -> Void)?
    var onOpenCharacters: (() -> Void)?
    var onQuit: (() -> Void)?

    private let world: WorldModel
    private let window: NSWindow
    private let petView = PetView(frame: CGRect(x: 0, y: 0, width: 220, height: 220))
    private var displayLink: Timer?
    private var lastTick = Date()
    private var velocity = CGVector(dx: 80, dy: 0)
    private var position = CGPoint(x: 240, y: 240)
    private var groundedSurface: Surface?
    private var edgeSurface: Surface?
    private var edgeInteractionUntil = Date.distantPast
    private var nextEdgeInteractionAt = Date.distantPast
    private var nextDecisionAt = Date()
    private var mouseEnteredAt: Date?
    private var nextHoverReactionAt = Date.distantPast
    private var nextFacingChangeAt = Date.distantPast
    private var isDragging = false
    private var dragSamples: [DragSample] = []

    private let size = CGSize(width: 220, height: 220)
    private let gravity: CGFloat = -1450
    private let windowBottomPeekGap: CGFloat = 1
    private let dragThrowSampleWindow: TimeInterval = 0.16
    private let dragThrowMultiplier: CGFloat = 0.82
    private let maxThrowVelocity = CGVector(dx: 920, dy: 860)
    private var characterPack: LoadedCharacterPack?

    var isVisible: Bool {
        window.isVisible
    }

    init(world: WorldModel, characterPack: LoadedCharacterPack?) {
        self.world = world
        window = NSWindow(
            contentRect: CGRect(origin: position, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.contentView = petView
        window.isReleasedWhenClosed = false

        if let characterPack {
            self.characterPack = characterPack
            petView.setCharacterPack(characterPack)
        }

        petView.onPrimaryClick = { [weak self] in
            self?.onOpenChat?(nil)
        }
        petView.onOpenSettings = { [weak self] in
            self?.onOpenSettings?()
        }
        petView.onOpenCharacters = { [weak self] in
            self?.onOpenCharacters?()
        }
        petView.onQuit = { [weak self] in
            self?.onQuit?()
        }
        petView.onDrag = { [weak self] location in
            self?.drag(to: location)
        }
        petView.onDragEnded = { [weak self] in
            self?.endDrag()
        }
    }

    func start() {
        world.start()
        window.orderFrontRegardless()
        displayLink = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func callToCursor() {
        let mouse = NSEvent.mouseLocation
        position = CGPoint(x: mouse.x - size.width / 2, y: mouse.y + 12)
        velocity = CGVector(dx: 0, dy: -120)
        groundedSurface = nil
        edgeSurface = nil
        petView.mood = .alert
        petView.speech = "왔어요"
        window.orderFrontRegardless()
        updateWindowFrame()
    }

    func toggleVisibility() {
        if window.isVisible {
            window.orderOut(nil)
        } else {
            callToCursor()
        }
    }

    func setCharacterPack(_ pack: LoadedCharacterPack) {
        characterPack = pack
        petView.setCharacterPack(pack)
    }

    func speak(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let sentence = trimmed
            .replacingOccurrences(of: "\n", with: " ")
            .prefix(54)
        petView.speech = String(sentence)
        petView.celebrate(nil)
    }

    private func tick() {
        let now = Date()
        let delta = min(now.timeIntervalSince(lastTick), 1.0 / 20.0)
        lastTick = now

        guard !isDragging else {
            edgeSurface = nil
            petView.advance(delta: delta)
            updateWindowFrame()
            return
        }

        world.setRefreshMode(active: shouldUseActiveWorldRefresh())
        world.refreshIfNeeded()
        reactToMouse(now: now)
        decideIfNeeded(now: now)
        integrate(delta: CGFloat(delta))
        petView.advance(delta: delta)
        updateWindowFrame()
    }

    private func decideIfNeeded(now: Date) {
        guard now >= nextDecisionAt else { return }
        nextDecisionAt = now.addingTimeInterval(Double.random(in: 1.0...3.2))

        if groundedSurface != nil {
            let roll = Double.random(in: 0...1)
            if roll < 0.16 {
                jumpToNearbySurface()
            } else if roll < 0.36 {
                velocity.dx = CGFloat.random(in: -120...120)
                petView.mood = .walk
            } else if roll < 0.48 {
                velocity.dx = 0
                petView.mood = .groom
            } else if roll < 0.58 {
                velocity.dx = 0
                petView.mood = .sleep
            } else {
                velocity.dx = 0
                petView.mood = Bool.random() ? .idle : .sit
            }
        }
    }

    private func integrate(delta: CGFloat) {
        if let edgeSurface {
            if Date() < edgeInteractionUntil {
                guard let updatedEdge = world.surface(id: edgeSurface.id) else {
                    release(from: edgeSurface)
                    return
                }
                self.edgeSurface = updatedEdge
                hold(on: updatedEdge)
                return
            }
            release(from: edgeSurface)
        }

        alignToGroundedSurfaceIfNeeded()
        let supportOffset = supportOffset(for: petView.mood)
        let previousBottom = position.y + supportOffset
        position.x += velocity.dx * delta
        position.y += velocity.dy * delta
        velocity.dy += gravity * delta

        if let screen = NSScreen.screens.first(where: { $0.frame.intersects(CGRect(origin: position, size: size)) }) ?? NSScreen.main {
            if position.x < screen.frame.minX {
                position.x = screen.frame.minX
                velocity.dx = abs(velocity.dx)
            } else if position.x + size.width > screen.frame.maxX {
                position.x = screen.frame.maxX - size.width
                velocity.dx = -abs(velocity.dx)
            }
        }

        rescueIfBelowScreen()

        let petFrame = CGRect(origin: position, size: size)
        if Date() >= nextEdgeInteractionAt,
           let edge = world.edgeInteraction(for: petFrame, velocity: velocity),
           Double.random(in: 0...1) < 0.34 {
            attach(to: edge)
            return
        }

        let wasAirborne = groundedSurface == nil
        if let landing = world.surfaceBelow(
            centerX: position.x + size.width / 2,
            halfWidth: size.width * 0.32,
            previousBottom: previousBottom,
            currentBottom: position.y + supportOffset
        ) {
            position.y = landing.frame.topSurfaceY - supportOffset
            velocity.dy = 0
            groundedSurface = landing
            if wasAirborne {
                petView.landEffect()
            }
            if abs(velocity.dx) > 8 {
                petView.mood = .walk
            } else if petView.mood == .alert || petView.mood == .play {
                petView.mood = .idle
            }
            alignToGroundedSurfaceIfNeeded()
        } else {
            groundedSurface = nil
            if velocity.dy < -30 {
                petView.mood = .fall
            }
        }
    }

    private func alignToGroundedSurfaceIfNeeded() {
        guard let groundedSurface, abs(velocity.dy) < 1 else { return }
        position.y = groundedSurface.frame.topSurfaceY - supportOffset(for: petView.mood)
    }

    private func shouldUseActiveWorldRefresh() -> Bool {
        edgeSurface != nil || groundedSurface == nil || abs(velocity.dx) > 25 || abs(velocity.dy) > 25
    }

    private func supportOffset(for mood: PetMood) -> CGFloat {
        characterPack?.visibleBoundsInPetWindow(for: mood.poseKey, windowSize: size)?.minY ?? 0
    }

    private func rescueIfBelowScreen() {
        let centerX = position.x + size.width / 2
        guard let ground = world.fallbackGround(centerX: centerX) else { return }
        let bottomLimit = ground.frame.topSurfaceY - size.height * 0.8
        guard position.y < bottomLimit else { return }

        let screen = NSScreen.screens.first { $0.frame.minX <= centerX && centerX <= $0.frame.maxX } ?? NSScreen.main
        position.y = (screen?.frame.maxY ?? ground.frame.topSurfaceY + 900) + 24
        velocity.dy = -120
        velocity.dx = CGFloat.random(in: -50...50)
        groundedSurface = nil
        edgeSurface = nil
        petView.mood = .fall
    }

    private func jumpToNearbySurface() {
        let center = CGPoint(x: position.x + size.width / 2, y: position.y)
        let candidates = world.surfaces
            .filter { $0.kind.isWalkable }
            .filter { $0.frame.horizontallyIntersects(centerX: center.x, halfWidth: 360) }
            .filter { abs($0.frame.topSurfaceY - center.y) < 280 }
            .filter { $0.id != groundedSurface?.id }

        guard let target = candidates.randomElement() else {
            velocity = CGVector(dx: CGFloat.random(in: -160...160), dy: CGFloat.random(in: 420...620))
            petView.mood = .jump
            return
        }

        let targetX = min(max(center.x, target.frame.minX + 32), target.frame.maxX - 32)
        let dx = targetX - center.x
        velocity = CGVector(dx: dx * 1.25, dy: CGFloat.random(in: 520...700))
        petView.mood = .jump
    }

    private func attach(to edge: Surface) {
        edgeSurface = edge
        groundedSurface = nil
        velocity = .zero
        edgeInteractionUntil = Date().addingTimeInterval(Double.random(in: 1.0...2.2))
        nextEdgeInteractionAt = Date().addingTimeInterval(3.0)
        hold(on: edge)

        switch edge.kind {
        case .windowBottom:
            petView.mood = .peek
            petView.speech = "여기서 볼게요"
        case .windowLeftEdge:
            petView.facingLeft = false
            petView.mood = .alert
            petView.speech = "잠깐만요"
        case .windowRightEdge:
            petView.facingLeft = true
            petView.mood = .alert
            petView.speech = "잡았어요"
        case .screenBottom, .dockTop, .windowTop:
            break
        }
    }

    private func hold(on edge: Surface) {
        switch edge.kind {
        case .windowBottom:
            position.x = min(max(position.x, edge.frame.minX - size.width * 0.42), edge.frame.maxX - size.width * 0.58)
            if let visibleBounds = characterPack?.visibleBoundsInPetWindow(for: .peek, windowSize: size) {
                position.y = edge.frame.midY - visibleBounds.minY - windowBottomPeekGap
            } else {
                position.y = edge.frame.midY - size.height + 208
            }
        case .windowLeftEdge:
            position.x = edge.frame.midX - size.width + 38
            position.y = min(max(position.y, edge.frame.minY - size.height * 0.36), edge.frame.maxY - size.height * 0.64)
        case .windowRightEdge:
            position.x = edge.frame.midX - 38
            position.y = min(max(position.y, edge.frame.minY - size.height * 0.36), edge.frame.maxY - size.height * 0.64)
        case .screenBottom, .dockTop, .windowTop:
            break
        }
    }

    private func release(from edge: Surface) {
        edgeSurface = nil
        groundedSurface = nil
        petView.mood = .jump

        switch edge.kind {
        case .windowBottom:
            velocity = CGVector(dx: CGFloat.random(in: -90...90), dy: -80)
            petView.mood = .fall
        case .windowLeftEdge:
            velocity = CGVector(dx: -180, dy: CGFloat.random(in: 320...460))
        case .windowRightEdge:
            velocity = CGVector(dx: 180, dy: CGFloat.random(in: 320...460))
        case .screenBottom, .dockTop, .windowTop:
            velocity = CGVector(dx: 0, dy: -120)
            petView.mood = .fall
        }
    }

    private func reactToMouse(now: Date) {
        let mouse = NSEvent.mouseLocation
        let petCenter = CGPoint(x: position.x + size.width / 2, y: position.y + size.height / 2)
        let dx = mouse.x - petCenter.x
        let dy = mouse.y - petCenter.y
        let distance = hypot(dx, dy)

        if distance < 220 {
            petView.gaze = CGVector(dx: dx / max(distance, 1), dy: dy / max(distance, 1))
            if mouseEnteredAt == nil {
                mouseEnteredAt = now
            }
            if groundedSurface != nil,
               distance < 96,
               now >= nextHoverReactionAt,
               now.timeIntervalSince(mouseEnteredAt ?? now) > 0.45,
               petView.mood != .sleep {
                petView.noticeCursor()
                nextHoverReactionAt = now.addingTimeInterval(2.4)
            }
        } else {
            petView.gaze = .zero
            mouseEnteredAt = nil
        }
    }

    private func drag(to location: CGPoint) {
        isDragging = true
        position = CGPoint(x: location.x - size.width / 2, y: location.y - size.height / 2)
        velocity = .zero
        groundedSurface = nil
        edgeSurface = nil
        petView.mood = .alert
        petView.speech = "어디로 가요?"
        recordDragSample(location)
    }

    private func recordDragSample(_ location: CGPoint) {
        let now = Date()
        dragSamples.append(DragSample(time: now, location: location))
        dragSamples.removeAll { now.timeIntervalSince($0.time) > dragThrowSampleWindow }
    }

    private func endDrag() {
        isDragging = false
        let releaseVelocity = dragReleaseVelocity()
        dragSamples.removeAll()

        if hypot(releaseVelocity.dx, releaseVelocity.dy) > 180 {
            velocity = releaseVelocity
            groundedSurface = nil
            edgeSurface = nil
            petView.mood = releaseVelocity.dy > 80 ? .jump : .fall
            if abs(releaseVelocity.dx) > 520 || abs(releaseVelocity.dy) > 520 {
                petView.speech = "꺅"
            }
        } else {
            velocity = CGVector(dx: releaseVelocity.dx * 0.18, dy: -80)
        }
    }

    private func dragReleaseVelocity() -> CGVector {
        guard let first = dragSamples.first, let last = dragSamples.last else {
            return CGVector(dx: 0, dy: -80)
        }

        let elapsed = max(last.time.timeIntervalSince(first.time), 0.016)
        let raw = CGVector(
            dx: (last.location.x - first.location.x) / elapsed,
            dy: (last.location.y - first.location.y) / elapsed
        )

        return CGVector(
            dx: clamp(raw.dx * dragThrowMultiplier, -maxThrowVelocity.dx, maxThrowVelocity.dx),
            dy: clamp(raw.dy * dragThrowMultiplier, -maxThrowVelocity.dy, maxThrowVelocity.dy)
        )
    }

    private func updateWindowFrame() {
        window.setFrame(CGRect(origin: position, size: size), display: true)
        updateFacingDirection()
    }

    private func updateFacingDirection() {
        let now = Date()
        let speed = velocity.dx
        guard abs(speed) > 38, now >= nextFacingChangeAt else { return }

        let shouldFaceLeft = speed < 0
        if petView.facingLeft != shouldFaceLeft {
            petView.facingLeft = shouldFaceLeft
            nextFacingChangeAt = now.addingTimeInterval(0.35)
        }
    }
}

private struct DragSample {
    var time: Date
    var location: CGPoint
}

private func clamp(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
    min(max(value, lower), upper)
}
