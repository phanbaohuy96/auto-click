import CoreGraphics
import Foundation

/// Giải một Vị trí ra toạ độ thật (EX-6).
///
/// Việc giải diễn ra ngay trước **mỗi lần lặp** của Bước, không phải một lần cho cả Bước —
/// nhờ vậy `theoConTrỏ` với số lần lặp lớn hơn 1 sẽ đi theo tay người dùng (DM-19).
struct TargetResolver: Sendable {
    let currentCursorPoint: @Sendable () -> CGPoint

    func resolve(_ target: StepTarget) -> CGPoint {
        switch target {
        case .cursor:
            return currentCursorPoint()
        case let .screenPoint(x, y):
            return CGPoint(x: x, y: y)
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
