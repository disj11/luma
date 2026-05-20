import AppKit

enum PetMood {
    case idle
    case walk
    case jump
    case fall
    case sit
    case alert
    case sleep
    case groom
    case play
    case happy
    case peek
}

struct PetParticle {
    enum Kind {
        case heart
        case sparkle
        case z
        case paw
    }

    var kind: Kind
    var position: CGPoint
    var velocity: CGVector
    var age: TimeInterval
    var lifetime: TimeInterval
    var size: CGFloat
}

final class PetView: NSView {
    var onPrimaryClick: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onOpenCharacters: (() -> Void)?
    var onQuit: (() -> Void)?
    var onDrag: ((CGPoint) -> Void)?
    var onDragEnded: (() -> Void)?

    var mood: PetMood = .idle {
        didSet {
            guard oldValue != mood else { return }
            previousMood = shouldCrossfade(from: oldValue, to: mood) ? oldValue : nil
            moodTransitionAge = 0
            needsDisplay = true
        }
    }
    var facingLeft = false { didSet { needsDisplay = true } }
    var gaze = CGVector.zero { didSet { needsDisplay = true } }
    var speech: String? { didSet { speechAge = 0; needsDisplay = true } }

    private var didDrag = false
    private var animationTime: TimeInterval = 0
    private var speechAge: TimeInterval = 0
    private var previousMood: PetMood?
    private var moodTransitionAge: TimeInterval = 1
    private var particles: [PetParticle] = []
    private var spriteRenderer: SpriteSheetPetRenderer?
    private let contextMenuTarget = PetContextMenuTarget()

    override var acceptsFirstResponder: Bool { true }

    func advance(delta: TimeInterval) {
        animationTime += delta
        speechAge += delta
        moodTransitionAge += delta
        if moodTransitionAge > 0.24 {
            previousMood = nil
        }

        if mood == .sleep && Int(animationTime * 2) % 5 == 0 && particles.count < 18 {
            emit(.z, count: 1)
        }

        for index in particles.indices {
            particles[index].age += delta
            particles[index].position.x += particles[index].velocity.dx * delta
            particles[index].position.y += particles[index].velocity.dy * delta
            particles[index].velocity.dy -= 26 * delta
        }
        particles.removeAll { $0.age >= $0.lifetime }
        needsDisplay = true
    }

    func celebrate(_ text: String? = nil) {
        if let text {
            speech = text
        }
        emit(.heart, count: 8)
        emit(.sparkle, count: 10)
        mood = .happy
    }

    func landEffect() {
        emit(.paw, count: 3)
        emit(.sparkle, count: 2)
    }

    func noticeCursor() {
        guard mood != .sleep, mood != .jump, mood != .fall, mood != .play, mood != .happy else { return }
        speech = Bool.random() ? "안녕!" : "여기 있어요"
        mood = .alert
    }

    func setCharacterPack(_ pack: LoadedCharacterPack) {
        spriteRenderer = SpriteSheetPetRenderer(pack: pack)
        mood = .happy
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill()

        drawParticles(behindPet: true)

        if let spriteRenderer {
            drawSpriteShadow()
            spriteRenderer.draw(
                mood: mood,
                previousMood: previousMood,
                transitionProgress: min(1, moodTransitionAge / 0.22),
                time: animationTime,
                facingLeft: facingLeft,
                in: bounds
            )
        } else {
            drawMissingCharacterPlaceholder()
        }

        drawParticles(behindPet: false)
        drawSpeechIfNeeded()
    }

    override func mouseDown(with event: NSEvent) {
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        didDrag = true
        onDrag?(NSEvent.mouseLocation)
    }

    override func mouseUp(with event: NSEvent) {
        if didDrag {
            onDragEnded?()
        } else {
            celebrate("부르셨어요?")
            onPrimaryClick?()
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(contextMenuItem(title: "대화하기", action: #selector(PetContextMenuTarget.openChat)))
        menu.addItem(.separator())
        menu.addItem(contextMenuItem(title: "설정", action: #selector(PetContextMenuTarget.openSettings)))
        menu.addItem(contextMenuItem(title: "캐릭터", action: #selector(PetContextMenuTarget.openCharacters)))
        menu.addItem(.separator())
        menu.addItem(contextMenuItem(title: "종료", action: #selector(PetContextMenuTarget.quit)))
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    private func contextMenuItem(title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = contextMenuTarget
        item.isEnabled = true
        return item
    }

    private var petRect: CGRect {
        bounds.insetBy(dx: 18, dy: 12)
    }

    private func drawMissingCharacterPlaceholder() {
        let rect = bounds.insetBy(dx: 42, dy: 44)
        NSColor(calibratedRed: 0.94, green: 0.95, blue: 0.98, alpha: 0.96).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 18, yRadius: 18).fill()
        NSColor(calibratedWhite: 0.2, alpha: 0.18).setStroke()
        NSBezierPath(roundedRect: rect, xRadius: 18, yRadius: 18).stroke()
        let text = "캐릭터 없음"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        text.draw(in: CGRect(x: rect.minX + 12, y: rect.midY - 9, width: rect.width - 24, height: 22), withAttributes: attrs)
    }

    private func shouldCrossfade(from oldMood: PetMood, to newMood: PetMood) -> Bool {
        if let spriteRenderer {
            return spriteRenderer.allowsCrossfade(from: oldMood, to: newMood)
        }
        if oldMood == .walk || newMood == .walk {
            return false
        }
        if oldMood == .alert || newMood == .alert {
            return false
        }
        if oldMood == .jump || newMood == .jump || oldMood == .fall || newMood == .fall {
            return false
        }
        return true
    }

    private func drawSpriteShadow() {
        let baseWidth: CGFloat
        let alpha: CGFloat
        switch mood {
        case .sleep:
            baseWidth = 132
            alpha = 0.18
        case .jump, .fall:
            baseWidth = 74
            alpha = 0.10
        case .play:
            baseWidth = 96 + abs(CGFloat(sin(animationTime * 9))) * 18
            alpha = 0.15
        case .walk:
            baseWidth = 104 + abs(CGFloat(sin(animationTime * 9))) * 8
            alpha = 0.16
        default:
            baseWidth = 112
            alpha = 0.16
        }
        drawSoftShadow(rect: CGRect(x: bounds.midX - baseWidth / 2, y: bounds.minY + 17, width: baseWidth, height: 14), alpha: alpha)
    }

    private func drawSoftShadow(rect: CGRect, alpha: CGFloat) {
        for layer in 0..<4 {
            let inset = CGFloat(layer) * -4
            let layerAlpha = alpha * CGFloat(4 - layer) / 4
            NSColor(calibratedWhite: 0.06, alpha: layerAlpha).setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: inset, dy: inset * 0.28)).fill()
        }
    }

    private func drawCat(in rect: CGRect) {
        let bodyColor = NSColor(calibratedRed: 0.96, green: 0.71, blue: 0.35, alpha: 1)
        let bellyColor = NSColor(calibratedRed: 1.0, green: 0.84, blue: 0.56, alpha: 1)
        let stroke = NSColor(calibratedRed: 0.24, green: 0.16, blue: 0.10, alpha: 1)
        let blush = NSColor(calibratedRed: 1.0, green: 0.45, blue: 0.50, alpha: 0.52)
        let stripe = NSColor(calibratedRed: 0.78, green: 0.45, blue: 0.16, alpha: 0.85)

        let pace = sin(animationTime * 8)
        let breathe = sin(animationTime * 2.4)
        let bob: CGFloat
        switch mood {
        case .walk: bob = CGFloat(abs(pace)) * 5
        case .jump: bob = 8
        case .fall: bob = -3
        case .sit: bob = -5
        case .alert: bob = 5
        case .sleep: bob = -8
        case .groom: bob = -2 + CGFloat(breathe) * 2
        case .play: bob = CGFloat(abs(sin(animationTime * 10))) * 7
        case .happy: bob = CGFloat(abs(sin(animationTime * 7))) * 6
        case .peek: bob = -12
        case .idle: bob = CGFloat(breathe) * 2
        }

        let bodyWidth: CGFloat = mood == .sit || mood == .sleep ? 76 : 68
        let bodyHeight: CGFloat = mood == .sleep ? 42 : 56
        let bodyRect = CGRect(
            x: rect.midX - bodyWidth / 2,
            y: rect.minY + 18 + bob,
            width: bodyWidth,
            height: bodyHeight
        )
        let headYOffset: CGFloat = mood == .sleep ? -2 : bodyRect.height - 4
        let headRect = CGRect(x: rect.midX - 40, y: bodyRect.minY + headYOffset, width: 80, height: 62)

        drawShadow(rect: CGRect(x: rect.midX - 46, y: rect.minY + 8, width: 92, height: 13))
        drawTail(from: bodyRect, color: bodyColor, stroke: stroke)

        bodyColor.setFill()
        stroke.setStroke()

        let body = NSBezierPath(roundedRect: bodyRect, xRadius: 30, yRadius: 28)
        body.fill()
        body.lineWidth = 2.4
        body.stroke()

        bellyColor.setFill()
        NSBezierPath(ovalIn: bodyRect.insetBy(dx: 17, dy: 9).offsetBy(dx: 0, dy: -4)).fill()

        drawLegs(bodyRect: bodyRect, stroke: stroke, fill: bodyColor, phase: pace)
        drawEars(headRect: headRect, fill: bodyColor, stroke: stroke)

        bodyColor.setFill()
        let head = NSBezierPath(roundedRect: headRect, xRadius: 31, yRadius: 29)
        head.fill()
        head.lineWidth = 2.4
        head.stroke()

        drawFace(headRect: headRect, stroke: stroke, blush: blush)
        drawStripes(headRect: headRect, color: stripe)
        drawWhiskers(headRect: headRect, stroke: stroke)

        if mood == .groom {
            drawGroomPaw(headRect: headRect, color: bodyColor, stroke: stroke)
        }
    }

    private func drawShadow(rect: CGRect) {
        NSColor(calibratedWhite: 0.08, alpha: 0.18).setFill()
        NSBezierPath(ovalIn: rect).fill()
    }

    private func drawTail(from bodyRect: CGRect, color: NSColor, stroke: NSColor) {
        let sway = CGFloat(sin(animationTime * (mood == .happy ? 9 : 3))) * 9
        let tail = NSBezierPath()
        tail.lineWidth = 11
        tail.lineCapStyle = .round
        tail.move(to: CGPoint(x: bodyRect.maxX - 4, y: bodyRect.midY + 8))
        tail.curve(
            to: CGPoint(x: bodyRect.maxX + 33, y: bodyRect.midY + 34 + sway),
            controlPoint1: CGPoint(x: bodyRect.maxX + 20, y: bodyRect.midY + 2),
            controlPoint2: CGPoint(x: bodyRect.maxX + 40, y: bodyRect.midY + 22 + sway)
        )
        color.setStroke()
        tail.stroke()

        tail.lineWidth = 2
        stroke.setStroke()
        tail.stroke()
    }

    private func drawLegs(bodyRect: CGRect, stroke: NSColor, fill: NSColor, phase: Double) {
        guard mood != .sleep else { return }
        fill.setFill()
        stroke.setStroke()
        let lift = mood == .walk ? CGFloat(phase) * 4 : 0
        for (index, x) in [bodyRect.minX + 14, bodyRect.maxX - 26].enumerated() {
            let y = bodyRect.minY - 7 + (index == 0 ? lift : -lift)
            let paw = NSBezierPath(roundedRect: CGRect(x: x, y: y, width: 20, height: 14), xRadius: 8, yRadius: 7)
            paw.fill()
            paw.lineWidth = 1.8
            paw.stroke()
        }
    }

    private func drawEars(headRect: CGRect, fill: NSColor, stroke: NSColor) {
        fill.setFill()
        stroke.setStroke()
        let earLean = mood == .alert || mood == .play ? 5.0 : 0.0

        let leftEar = NSBezierPath()
        leftEar.move(to: CGPoint(x: headRect.minX + 10, y: headRect.maxY - 11))
        leftEar.line(to: CGPoint(x: headRect.minX + 24 + earLean, y: headRect.maxY + 20))
        leftEar.line(to: CGPoint(x: headRect.minX + 39, y: headRect.maxY - 5))
        leftEar.close()

        let rightEar = NSBezierPath()
        rightEar.move(to: CGPoint(x: headRect.maxX - 10, y: headRect.maxY - 11))
        rightEar.line(to: CGPoint(x: headRect.maxX - 24 + earLean, y: headRect.maxY + 20))
        rightEar.line(to: CGPoint(x: headRect.maxX - 39, y: headRect.maxY - 5))
        rightEar.close()

        leftEar.fill()
        rightEar.fill()
        leftEar.lineWidth = 2.4
        rightEar.lineWidth = 2.4
        leftEar.stroke()
        rightEar.stroke()

        NSColor(calibratedRed: 1, green: 0.62, blue: 0.62, alpha: 0.75).setFill()
        NSBezierPath(roundedRect: CGRect(x: headRect.minX + 21, y: headRect.maxY - 3, width: 12, height: 16), xRadius: 6, yRadius: 6).fill()
        NSBezierPath(roundedRect: CGRect(x: headRect.maxX - 33, y: headRect.maxY - 3, width: 12, height: 16), xRadius: 6, yRadius: 6).fill()
    }

    private func drawFace(headRect: CGRect, stroke: NSColor, blush: NSColor) {
        stroke.setFill()
        let blink = Int(animationTime * 1.7) % 11 == 0
        let eyeYOffset: CGFloat = mood == .sit || mood == .sleep ? -3 : 0
        let lookX = max(-4, min(4, gaze.dx * 5))
        let lookY = max(-2, min(3, gaze.dy * 4))

        if mood == .sleep || blink {
            drawClosedEye(center: CGPoint(x: headRect.midX - 20, y: headRect.midY + eyeYOffset))
            drawClosedEye(center: CGPoint(x: headRect.midX + 20, y: headRect.midY + eyeYOffset))
        } else {
            NSBezierPath(ovalIn: CGRect(x: headRect.midX - 25 + lookX, y: headRect.midY - 1 + eyeYOffset + lookY, width: 9, height: 13)).fill()
            NSBezierPath(ovalIn: CGRect(x: headRect.midX + 16 + lookX, y: headRect.midY - 1 + eyeYOffset + lookY, width: 9, height: 13)).fill()
            NSColor.white.withAlphaComponent(0.72).setFill()
            NSBezierPath(ovalIn: CGRect(x: headRect.midX - 22 + lookX, y: headRect.midY + 7 + eyeYOffset + lookY, width: 3, height: 3)).fill()
            NSBezierPath(ovalIn: CGRect(x: headRect.midX + 19 + lookX, y: headRect.midY + 7 + eyeYOffset + lookY, width: 3, height: 3)).fill()
        }

        stroke.setFill()
        let nose = NSBezierPath()
        nose.move(to: CGPoint(x: headRect.midX - 5, y: headRect.midY - 11))
        nose.line(to: CGPoint(x: headRect.midX + 5, y: headRect.midY - 11))
        nose.line(to: CGPoint(x: headRect.midX, y: headRect.midY - 17))
        nose.close()
        nose.fill()

        let smileDepth: CGFloat = mood == .happy || mood == .play ? -23 : -20
        let mouth = NSBezierPath()
        mouth.lineWidth = 1.7
        mouth.move(to: CGPoint(x: headRect.midX, y: headRect.midY - 17))
        mouth.curve(
            to: CGPoint(x: headRect.midX - 11, y: headRect.midY + smileDepth),
            controlPoint1: CGPoint(x: headRect.midX - 4, y: headRect.midY - 21),
            controlPoint2: CGPoint(x: headRect.midX - 8, y: headRect.midY + smileDepth - 1)
        )
        mouth.move(to: CGPoint(x: headRect.midX, y: headRect.midY - 17))
        mouth.curve(
            to: CGPoint(x: headRect.midX + 11, y: headRect.midY + smileDepth),
            controlPoint1: CGPoint(x: headRect.midX + 4, y: headRect.midY - 21),
            controlPoint2: CGPoint(x: headRect.midX + 8, y: headRect.midY + smileDepth - 1)
        )
        stroke.setStroke()
        mouth.stroke()

        blush.setFill()
        NSBezierPath(ovalIn: CGRect(x: headRect.minX + 11, y: headRect.midY - 17, width: 14, height: 8)).fill()
        NSBezierPath(ovalIn: CGRect(x: headRect.maxX - 25, y: headRect.midY - 17, width: 14, height: 8)).fill()
    }

    private func drawClosedEye(center: CGPoint) {
        let path = NSBezierPath()
        path.lineWidth = 2.2
        path.move(to: CGPoint(x: center.x - 7, y: center.y))
        path.curve(to: CGPoint(x: center.x + 7, y: center.y), controlPoint1: CGPoint(x: center.x - 3, y: center.y - 4), controlPoint2: CGPoint(x: center.x + 3, y: center.y - 4))
        path.stroke()
    }

    private func drawStripes(headRect: CGRect, color: NSColor) {
        color.setStroke()
        for x in [-12.0, 0.0, 12.0] {
            let stripe = NSBezierPath()
            stripe.lineWidth = 2.2
            stripe.lineCapStyle = .round
            stripe.move(to: CGPoint(x: headRect.midX + x, y: headRect.maxY - 8))
            stripe.line(to: CGPoint(x: headRect.midX + x * 0.45, y: headRect.maxY - 22))
            stripe.stroke()
        }
    }

    private func drawWhiskers(headRect: CGRect, stroke: NSColor) {
        stroke.setStroke()
        for offset in [-4.0, -12.0] {
            let left = NSBezierPath()
            left.lineWidth = 1.5
            left.move(to: CGPoint(x: headRect.midX - 12, y: headRect.midY + offset))
            left.line(to: CGPoint(x: headRect.minX - 8, y: headRect.midY + offset + 5))
            left.stroke()

            let right = NSBezierPath()
            right.lineWidth = 1.5
            right.move(to: CGPoint(x: headRect.midX + 12, y: headRect.midY + offset))
            right.line(to: CGPoint(x: headRect.maxX + 8, y: headRect.midY + offset + 5))
            right.stroke()
        }
    }

    private func drawGroomPaw(headRect: CGRect, color: NSColor, stroke: NSColor) {
        color.setFill()
        stroke.setStroke()
        let paw = NSBezierPath(roundedRect: CGRect(x: headRect.midX + 17, y: headRect.midY - 4, width: 22, height: 18), xRadius: 9, yRadius: 9)
        paw.fill()
        paw.lineWidth = 1.8
        paw.stroke()
    }

    private func drawSpeechIfNeeded() {
        guard let speech, speechAge < 4.4 else { return }
        let displayText = speech
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(42)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: NSColor(calibratedRed: 0.20, green: 0.14, blue: 0.09, alpha: 1)
        ]
        let maxWidth = bounds.width - 28
        let measured = (String(displayText) as NSString).boundingRect(
            with: CGSize(width: maxWidth - 24, height: 42),
            options: [.usesLineFragmentOrigin],
            attributes: attrs
        )
        let width = min(maxWidth, max(52, ceil(measured.width) + 24))
        let height = min(56, max(30, ceil(measured.height) + 14))
        let bubble = CGRect(
            x: max(4, min(bounds.width - width - 4, (bounds.width - width) / 2)),
            y: bounds.maxY - height - 24,
            width: width,
            height: height
        )
        NSColor.white.withAlphaComponent(0.94).setFill()
        NSBezierPath(roundedRect: bubble, xRadius: 13, yRadius: 13).fill()
        NSColor(calibratedWhite: 0, alpha: 0.14).setStroke()
        NSBezierPath(roundedRect: bubble, xRadius: 13, yRadius: 13).stroke()
        String(displayText).draw(in: bubble.insetBy(dx: 12, dy: 7), withAttributes: attrs)
    }

    private func emit(_ kind: PetParticle.Kind, count: Int) {
        for _ in 0..<count {
            particles.append(PetParticle(
                kind: kind,
                position: CGPoint(x: bounds.midX + CGFloat.random(in: -26...26), y: bounds.midY + CGFloat.random(in: 8...44)),
                velocity: CGVector(dx: CGFloat.random(in: -24...24), dy: CGFloat.random(in: 22...78)),
                age: 0,
                lifetime: Double.random(in: 0.9...1.8),
                size: CGFloat.random(in: 8...16)
            ))
        }
    }

    private func drawParticles(behindPet: Bool) {
        for particle in particles {
            let shouldDrawBehind = particle.kind == .paw
            guard shouldDrawBehind == behindPet else { continue }
            let alpha = max(0, 1 - particle.age / particle.lifetime)
            let rect = CGRect(x: particle.position.x, y: particle.position.y, width: particle.size, height: particle.size)
            switch particle.kind {
            case .heart:
                drawHeart(in: rect, alpha: alpha)
            case .sparkle:
                drawSparkle(in: rect, alpha: alpha)
            case .z:
                drawTextParticle("Z", in: rect, alpha: alpha)
            case .paw:
                drawPaw(in: rect, alpha: alpha)
            }
        }
    }

    private func drawHeart(in rect: CGRect, alpha: Double) {
        NSColor(calibratedRed: 1, green: 0.28, blue: 0.42, alpha: alpha).setFill()
        let path = NSBezierPath()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.curve(to: CGPoint(x: rect.minX, y: rect.midY), controlPoint1: CGPoint(x: rect.midX - rect.width * 0.45, y: rect.minY + rect.height * 0.25), controlPoint2: CGPoint(x: rect.minX, y: rect.midY - rect.height * 0.1))
        path.curve(to: CGPoint(x: rect.midX, y: rect.maxY), controlPoint1: CGPoint(x: rect.minX, y: rect.maxY), controlPoint2: CGPoint(x: rect.midX - rect.width * 0.2, y: rect.maxY))
        path.curve(to: CGPoint(x: rect.maxX, y: rect.midY), controlPoint1: CGPoint(x: rect.midX + rect.width * 0.2, y: rect.maxY), controlPoint2: CGPoint(x: rect.maxX, y: rect.maxY))
        path.curve(to: CGPoint(x: rect.midX, y: rect.minY), controlPoint1: CGPoint(x: rect.maxX, y: rect.midY - rect.height * 0.1), controlPoint2: CGPoint(x: rect.midX + rect.width * 0.45, y: rect.minY + rect.height * 0.25))
        path.fill()
    }

    private func drawSparkle(in rect: CGRect, alpha: Double) {
        NSColor(calibratedRed: 1, green: 0.86, blue: 0.25, alpha: alpha).setFill()
        let path = NSBezierPath()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.line(to: CGPoint(x: rect.midX + 3, y: rect.midY + 3))
        path.line(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.line(to: CGPoint(x: rect.midX + 3, y: rect.midY - 3))
        path.line(to: CGPoint(x: rect.midX, y: rect.minY))
        path.line(to: CGPoint(x: rect.midX - 3, y: rect.midY - 3))
        path.line(to: CGPoint(x: rect.minX, y: rect.midY))
        path.line(to: CGPoint(x: rect.midX - 3, y: rect.midY + 3))
        path.close()
        path.fill()
    }

    private func drawPaw(in rect: CGRect, alpha: Double) {
        NSColor(calibratedWhite: 0.18, alpha: alpha * 0.26).setFill()
        NSBezierPath(ovalIn: rect.insetBy(dx: 3, dy: 2)).fill()
        for point in [
            CGPoint(x: rect.minX + 2, y: rect.midY + 4),
            CGPoint(x: rect.midX - 2, y: rect.maxY - 2),
            CGPoint(x: rect.maxX - 5, y: rect.midY + 4)
        ] {
            NSBezierPath(ovalIn: CGRect(x: point.x, y: point.y, width: 4, height: 5)).fill()
        }
    }

    private func drawTextParticle(_ text: String, in rect: CGRect, alpha: Double) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 15),
            .foregroundColor: NSColor(calibratedRed: 0.30, green: 0.46, blue: 1, alpha: alpha)
        ]
        text.draw(in: rect, withAttributes: attrs)
    }
}
