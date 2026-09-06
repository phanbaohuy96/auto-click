import CoreGraphics
import Foundation

enum ClickEventRoute: Equatable {
    case systemEventTap
}

/// Quyết định một sự kiện có toạ độ có được phép phát hay không, dựa trên Ứng dụng khoá (EX-10).
///
/// Chỉ áp dụng cho sự kiện **có toạ độ**. Sự kiện bàn phím không có toạ độ nên phải bảo vệ bằng
/// cách khác, xem `SF-4`.
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
