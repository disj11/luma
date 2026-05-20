import AppKit

private struct SpriteMotion {
    var offset = CGPoint.zero
    var scaleX: CGFloat = 1
    var scaleY: CGFloat = 1
    var rotation: CGFloat = 0
}

final class SpriteSheetPetRenderer {
    private let pack: LoadedCharacterPack

    init(pack: LoadedCharacterPack) {
        self.pack = pack
    }

    func allowsCrossfade(from oldMood: PetMood, to newMood: PetMood) -> Bool {
        pose(for: oldMood).crossfade ?? true && pose(for: newMood).crossfade ?? true
    }

    func draw(
        mood: PetMood,
        previousMood: PetMood?,
        transitionProgress: TimeInterval,
        time: TimeInterval,
        facingLeft: Bool,
        in bounds: CGRect
    ) {
        let context = NSGraphicsContext.current?.cgContext
        context?.saveGState()
        if facingLeft {
            context?.translateBy(x: bounds.width, y: 0)
            context?.scaleBy(x: -1, y: 1)
        }

        let eased = easeOutBack(CGFloat(transitionProgress))
        if let previousMood, transitionProgress < 1 {
            drawPose(
                mood: previousMood,
                time: time,
                in: bounds,
                alpha: max(0, 1 - CGFloat(transitionProgress) * 1.2),
                transitionScale: 1 - 0.025 * eased
            )
        }

        drawPose(
            mood: mood,
            time: time,
            in: bounds,
            alpha: min(1, 0.2 + eased),
            transitionScale: 0.95 + 0.05 * eased
        )

        context?.restoreGState()
    }

    private func drawPose(mood: PetMood, time: TimeInterval, in bounds: CGRect, alpha: CGFloat, transitionScale: CGFloat) {
        let pose = pose(for: mood)
        let image = image(for: mood)
        var target = targetRect(for: pose, in: bounds)
        let motion = motion(for: pose.motion ?? mood.poseKey.rawValue, time: time)
        target = target.offsetBy(dx: motion.offset.x, dy: motion.offset.y)

        let context = NSGraphicsContext.current?.cgContext
        context?.saveGState()
        context?.translateBy(x: target.midX, y: target.midY)
        context?.rotate(by: motion.rotation)
        context?.scaleBy(x: motion.scaleX * transitionScale, y: motion.scaleY * transitionScale)
        context?.translateBy(x: -target.midX, y: -target.midY)

        image.draw(
            in: target,
            from: CGRect(origin: .zero, size: image.size),
            operation: .sourceOver,
            fraction: alpha,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high.rawValue]
        )
        context?.restoreGState()
    }

    private func image(for mood: PetMood) -> NSImage {
        let key = mood.poseKey
        return pack.images[key] ?? pack.images[pack.manifest.defaultPose]!
    }

    private func pose(for mood: PetMood) -> CharacterPack.Pose {
        let key = mood.poseKey
        return pack.manifest.pose(for: key) ?? pack.manifest.pose(for: pack.manifest.defaultPose)!
    }

    private func motion(for name: String, time: TimeInterval) -> SpriteMotion {
        let slow = CGFloat(sin(time * 2.3))
        let fast = CGFloat(sin(time * 8.5))
        let bounce = abs(CGFloat(sin(time * 9.0)))

        switch name {
        case "breathe", "idle":
            return SpriteMotion(offset: CGPoint(x: 0, y: slow * 2), scaleX: 1 - slow * 0.006, scaleY: 1 + slow * 0.014)
        case "walk":
            return SpriteMotion(offset: CGPoint(x: fast * 0.9, y: bounce * 5), scaleX: 1 + bounce * 0.016, scaleY: 1 - bounce * 0.020, rotation: fast * 0.022)
        case "jump":
            return SpriteMotion(offset: CGPoint(x: 0, y: 8 + slow * 2), scaleX: 0.96, scaleY: 1.06, rotation: -0.06)
        case "fall":
            return SpriteMotion(offset: CGPoint(x: 0, y: -2), scaleX: 1.04, scaleY: 0.98, rotation: 0.05)
        case "sit":
            return SpriteMotion(offset: CGPoint(x: 0, y: slow), scaleX: 1 + slow * 0.004, scaleY: 1 - slow * 0.004)
        case "alert":
            return SpriteMotion(offset: CGPoint(x: fast * 0.45, y: 3 + bounce * 1.2), scaleX: 1.01, scaleY: 1.01, rotation: fast * 0.008)
        case "sleep":
            return SpriteMotion(offset: CGPoint(x: 0, y: slow * 1.2), scaleX: 1 + slow * 0.01, scaleY: 1 - slow * 0.006)
        case "groom", "wave":
            return SpriteMotion(offset: CGPoint(x: 0, y: slow * 2), scaleX: 1, scaleY: 1, rotation: CGFloat(sin(time * 5.2)) * 0.025)
        case "play":
            return SpriteMotion(offset: CGPoint(x: fast * 3.0, y: bounce * 7), scaleX: 1.05 - bounce * 0.03, scaleY: 0.98 + bounce * 0.045, rotation: fast * 0.055)
        case "happy":
            return SpriteMotion(offset: CGPoint(x: fast * 1.4, y: bounce * 8), scaleX: 1 + bounce * 0.02, scaleY: 1 - bounce * 0.018)
        case "peek":
            return SpriteMotion(offset: CGPoint(x: fast * 0.6, y: slow * 1.2), scaleX: 1, scaleY: 1)
        default:
            return SpriteMotion()
        }
    }

    private func targetRect(for pose: CharacterPack.Pose, in bounds: CGRect) -> CGRect {
        let baseSize = min(bounds.width - 20, bounds.height - 20, pack.manifest.render.baseSize)
        let size = baseSize * (pose.scale ?? 1)
        let y = bounds.minY + pack.manifest.render.baseYOffset + (pose.yOffset ?? 0)

        return CGRect(
            x: bounds.midX - size / 2,
            y: y,
            width: size,
            height: size
        )
    }

    private func easeOutBack(_ value: CGFloat) -> CGFloat {
        let x = min(1, max(0, value))
        let c1: CGFloat = 1.70158
        let c3 = c1 + 1
        let t = x - 1
        return 1 + c3 * t * t * t + c1 * t * t
    }
}
