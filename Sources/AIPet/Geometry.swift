import AppKit

enum SurfaceKind: String {
    case screenBottom
    case dockTop
    case windowTop
    case windowBottom
    case windowLeftEdge
    case windowRightEdge

    var isWalkable: Bool {
        switch self {
        case .screenBottom, .dockTop, .windowTop:
            return true
        case .windowBottom, .windowLeftEdge, .windowRightEdge:
            return false
        }
    }

    var isWindowEdge: Bool {
        switch self {
        case .windowBottom, .windowLeftEdge, .windowRightEdge:
            return true
        case .screenBottom, .dockTop, .windowTop:
            return false
        }
    }
}

struct Surface: Equatable {
    let id: String
    let frame: CGRect
    let kind: SurfaceKind
    let zIndex: Int
    let ownerName: String?
}

extension CGRect {
    var topSurfaceY: CGFloat { maxY }

    func horizontallyIntersects(centerX: CGFloat, halfWidth: CGFloat) -> Bool {
        centerX + halfWidth >= minX && centerX - halfWidth <= maxX
    }
}
