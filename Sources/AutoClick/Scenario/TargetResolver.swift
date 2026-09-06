import CoreGraphics
import Foundation

enum TargetResolutionError: LocalizedError, Equatable {
    case anchorWindowUnavailable
}

/// Giải một Vị trí ra toạ độ thật (EX-6, EX-7).
///
/// Việc giải diễn ra ngay trước **mỗi lần lặp** của Bước, không phải một lần cho cả Bước —
/// nhờ vậy `theoConTrỏ` với số lần lặp lớn hơn 1 sẽ đi theo tay người dùng (DM-19).
///
/// Khung Cửa sổ neo được truyền vào chứ không tự đi hỏi Accessibility: giữ cho việc giải Vị trí
/// là một phép biến đổi thuần tuý, kiểm chứng được mà không cần dựng cửa sổ thật.
struct TargetResolver: Sendable {
    let currentCursorPoint: @Sendable () -> CGPoint

    func resolve(_ target: StepTarget, anchorWindowFrame: CGRect?) throws -> CGPoint {
        switch target {
        case .cursor:
            return currentCursorPoint()
        case let .screenPoint(x, y):
            return CGPoint(x: x, y: y)
        case let .windowRelative(corner, dx, dy):
            guard let anchorWindowFrame else {
                throw TargetResolutionError.anchorWindowUnavailable
            }
            return WindowAnchor.resolve(
                WindowAnchor.Offset(corner: corner, dx: dx, dy: dy),
                in: anchorWindowFrame
            )
        }
    }
}

extension TargetResolver {
    /// Bộ giải dùng lúc chạy thật: đọc vị trí con trỏ trong không gian toạ độ của `CGEvent`
    /// (gốc ở góc trên-trái màn hình chính, đơn vị point — DM-12).
    static let live = TargetResolver(
        currentCursorPoint: { CGEvent(source: nil)?.location ?? .zero }
    )
}
