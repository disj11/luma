import AppKit
import CoreGraphics

final class WorldModel {
    private(set) var surfaces: [Surface] = []
    private var lastRefresh = Date.distantPast
    private let refreshInterval: TimeInterval = 0.35
    private let ownPID = Int(ProcessInfo.processInfo.processIdentifier)

    func start() {
        refresh()
    }

    func refreshIfNeeded() {
        guard Date().timeIntervalSince(lastRefresh) >= refreshInterval else { return }
        refresh()
    }

    func surfaceBelow(centerX: CGFloat, halfWidth: CGFloat, previousBottom: CGFloat, currentBottom: CGFloat) -> Surface? {
        let candidates = surfaces.filter { surface in
            let y = surface.frame.topSurfaceY
            return surface.kind.isWalkable
                && surface.frame.horizontallyIntersects(centerX: centerX, halfWidth: halfWidth)
                && previousBottom >= y
                && currentBottom <= y + 8
        }

        return candidates.sorted {
            if $0.frame.topSurfaceY == $1.frame.topSurfaceY {
                return $0.zIndex > $1.zIndex
            }
            return $0.frame.topSurfaceY > $1.frame.topSurfaceY
        }.first
    }

    func fallbackGround(centerX: CGFloat) -> Surface? {
        let screenSurfaces = surfaces.filter { $0.kind == .screenBottom && $0.frame.minX <= centerX && centerX <= $0.frame.maxX }
        return screenSurfaces.max { $0.frame.topSurfaceY < $1.frame.topSurfaceY }
            ?? surfaces.filter { $0.kind == .screenBottom }.first
    }

    func edgeInteraction(for petFrame: CGRect, velocity: CGVector) -> Surface? {
        let candidates = surfaces.filter { surface in
            guard surface.kind.isWindowEdge else { return false }
            switch surface.kind {
            case .windowBottom:
                let petTop = petFrame.maxY
                return velocity.dy < -120
                    && abs(petTop - surface.frame.midY) < 34
                    && petFrame.midX >= surface.frame.minX
                    && petFrame.midX <= surface.frame.maxX
            case .windowLeftEdge:
                return velocity.dx > 90
                    && abs(petFrame.maxX - surface.frame.midX) < 28
                    && petFrame.midY >= surface.frame.minY
                    && petFrame.midY <= surface.frame.maxY
            case .windowRightEdge:
                return velocity.dx < -90
                    && abs(petFrame.minX - surface.frame.midX) < 28
                    && petFrame.midY >= surface.frame.minY
                    && petFrame.midY <= surface.frame.maxY
            case .screenBottom, .dockTop, .windowTop:
                return false
            }
        }

        return candidates.sorted {
            if $0.zIndex == $1.zIndex {
                return $0.frame.width * $0.frame.height > $1.frame.width * $1.frame.height
            }
            return $0.zIndex > $1.zIndex
        }.first
    }

    private func refresh() {
        lastRefresh = Date()
        var next: [Surface] = []

        for screen in NSScreen.screens {
            next.append(Surface(
                id: "screen-\(screen.localizedName)",
                frame: CGRect(x: screen.frame.minX, y: screen.frame.minY - 6, width: screen.frame.width, height: 6),
                kind: .screenBottom,
                zIndex: -10,
                ownerName: screen.localizedName
            ))

            if screen.visibleFrame.minY > screen.frame.minY + 12 {
                next.append(Surface(
                    id: "dock-\(screen.localizedName)",
                    frame: CGRect(
                        x: screen.visibleFrame.minX,
                        y: screen.visibleFrame.minY - 6,
                        width: screen.visibleFrame.width,
                        height: 6
                    ),
                    kind: .dockTop,
                    zIndex: 50,
                    ownerName: "Dock"
                ))
            }
        }

        next.append(contentsOf: readWindowSurfaces())
        surfaces = next
    }

    private func readWindowSurfaces() -> [Surface] {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        var result: [Surface] = []
        var frontWindowFrames: [CGRect] = []
        for (index, info) in list.enumerated() {
            guard let pid = info[kCGWindowOwnerPID as String] as? Int, pid != ownPID else { continue }
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
            guard let boundsDict = info[kCGWindowBounds as String] as? NSDictionary else { continue }
            guard let cgBounds = CGRect(dictionaryRepresentation: boundsDict) else { continue }
            guard cgBounds.width >= 120, cgBounds.height >= 80 else { continue }

            let appKitFrame = convertWindowServerRect(cgBounds)
            guard appKitFrame.width >= 120, appKitFrame.height >= 80 else { continue }
            let owner = info[kCGWindowOwnerName as String] as? String
            let windowNumber = info[kCGWindowNumber as String] as? Int ?? index

            let insetX: CGFloat = 8
            let edgeInset: CGFloat = 24
            let zIndex = 1000 - index

            let topEdge = CGRect(
                x: appKitFrame.minX + insetX,
                y: appKitFrame.maxY - 6,
                width: max(0, appKitFrame.width - insetX * 2),
                height: 6
            )
            result.append(contentsOf: visibleHorizontalEdgeSegments(
                frame: topEdge,
                kind: .windowTop,
                idPrefix: "window-\(windowNumber)",
                zIndex: zIndex,
                owner: owner,
                occluders: frontWindowFrames
            ))

            let bottomEdge = CGRect(
                x: appKitFrame.minX + edgeInset,
                y: appKitFrame.minY - 3,
                width: max(0, appKitFrame.width - edgeInset * 2),
                height: 6
            )
            result.append(contentsOf: visibleHorizontalEdgeSegments(
                frame: bottomEdge,
                kind: .windowBottom,
                idPrefix: "window-\(windowNumber)-bottom",
                zIndex: zIndex,
                owner: owner,
                occluders: frontWindowFrames
            ))

            let leftEdge = CGRect(
                x: appKitFrame.minX - 3,
                y: appKitFrame.minY + edgeInset,
                width: 6,
                height: max(0, appKitFrame.height - edgeInset * 2)
            )
            result.append(contentsOf: visibleVerticalEdgeSegments(
                frame: leftEdge,
                kind: .windowLeftEdge,
                idPrefix: "window-\(windowNumber)-left",
                zIndex: zIndex,
                owner: owner,
                occluders: frontWindowFrames
            ))

            let rightEdge = CGRect(
                x: appKitFrame.maxX - 3,
                y: appKitFrame.minY + edgeInset,
                width: 6,
                height: max(0, appKitFrame.height - edgeInset * 2)
            )
            result.append(contentsOf: visibleVerticalEdgeSegments(
                frame: rightEdge,
                kind: .windowRightEdge,
                idPrefix: "window-\(windowNumber)-right",
                zIndex: zIndex,
                owner: owner,
                occluders: frontWindowFrames
            ))

            frontWindowFrames.append(appKitFrame)
        }
        return result
    }

    private func visibleHorizontalEdgeSegments(
        frame: CGRect,
        kind: SurfaceKind,
        idPrefix: String,
        zIndex: Int,
        owner: String?,
        occluders: [CGRect]
    ) -> [Surface] {
        var intervals = [ClosedRange<CGFloat>(uncheckedBounds: (frame.minX, frame.maxX))]
        let probe = frame.insetBy(dx: 0, dy: -10)

        for occluder in occluders where occluder.intersects(probe) {
            intervals = intervals.flatMap { subtract($0, covered: occluder.minX...occluder.maxX) }
        }

        return intervals.enumerated().compactMap { offset, interval in
            let width = interval.upperBound - interval.lowerBound
            guard width >= 72 else { return nil }
            return Surface(
                id: "\(idPrefix)-\(offset)",
                frame: CGRect(x: interval.lowerBound, y: frame.minY, width: width, height: frame.height),
                kind: kind,
                zIndex: zIndex,
                ownerName: owner
            )
        }
    }

    private func visibleVerticalEdgeSegments(
        frame: CGRect,
        kind: SurfaceKind,
        idPrefix: String,
        zIndex: Int,
        owner: String?,
        occluders: [CGRect]
    ) -> [Surface] {
        var intervals = [ClosedRange<CGFloat>(uncheckedBounds: (frame.minY, frame.maxY))]
        let probe = frame.insetBy(dx: -10, dy: 0)

        for occluder in occluders where occluder.intersects(probe) {
            intervals = intervals.flatMap { subtract($0, covered: occluder.minY...occluder.maxY) }
        }

        return intervals.enumerated().compactMap { offset, interval in
            let height = interval.upperBound - interval.lowerBound
            guard height >= 72 else { return nil }
            return Surface(
                id: "\(idPrefix)-\(offset)",
                frame: CGRect(x: frame.minX, y: interval.lowerBound, width: frame.width, height: height),
                kind: kind,
                zIndex: zIndex,
                ownerName: owner
            )
        }
    }

    private func subtract(_ interval: ClosedRange<CGFloat>, covered: ClosedRange<CGFloat>) -> [ClosedRange<CGFloat>] {
        let overlapMin = max(interval.lowerBound, covered.lowerBound)
        let overlapMax = min(interval.upperBound, covered.upperBound)
        guard overlapMin < overlapMax else {
            return [interval]
        }

        var result: [ClosedRange<CGFloat>] = []
        if interval.lowerBound < overlapMin {
            result.append(ClosedRange(uncheckedBounds: (interval.lowerBound, overlapMin)))
        }
        if overlapMax < interval.upperBound {
            result.append(ClosedRange(uncheckedBounds: (overlapMax, interval.upperBound)))
        }
        return result
    }

    private func convertWindowServerRect(_ rect: CGRect) -> CGRect {
        let union = NSScreen.screens.reduce(CGRect.null) { partial, screen in
            partial.union(screen.frame)
        }
        let y = union.maxY - rect.origin.y - rect.height
        return CGRect(x: rect.origin.x, y: y, width: rect.width, height: rect.height)
    }
}
