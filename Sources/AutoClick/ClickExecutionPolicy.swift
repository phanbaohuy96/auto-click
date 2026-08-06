import CoreGraphics
import Foundation

enum ClickEventRoute: Equatable {
    case systemEventTap
}

struct ClickPositionPolicy {
    let fixedPoint: CGPoint?

    func pointForNextClick(currentCursorPoint: CGPoint) -> CGPoint {
        fixedPoint ?? currentCursorPoint
    }
}

enum ClickRoutingPolicy {
    static func route(
        targetProcessIdentifier: pid_t?,
        processIdentifierAtPoint: pid_t?
    ) -> ClickEventRoute? {
        guard let targetProcessIdentifier else { return .systemEventTap }
        guard processIdentifierAtPoint == targetProcessIdentifier else { return nil }
        return .systemEventTap
    }
}
