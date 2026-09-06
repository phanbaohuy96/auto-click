import CoreGraphics
import Foundation

enum TargetResolutionError: LocalizedError, Equatable {
    case anchorWindowUnavailable
    /// Vị trí này phải đi tìm mục tiêu trên màn hình nên không giải được đồng bộ.
    case requiresRecognition
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
        case .template, .text:
            throw TargetResolutionError.requiresRecognition
        }
    }

    /// Giải một **Vùng tìm** ra hình chữ nhật thật.
    ///
    /// [ADR-0006]: vùng tương đối cửa sổ mà không giải được thì **lùi về phạm vi mặc định**
    /// (`RG-7`) chứ không báo lỗi — Vùng tìm không bao giờ được ràng buộc Kịch bản phải có
    /// Ứng dụng khoá.
    func resolve(_ region: SearchRegion?, anchorWindowFrame: CGRect?) -> CGRect? {
        switch region {
        case nil:
            return anchorWindowFrame
        case let .screenRect(x, y, width, height):
            return CGRect(x: x, y: y, width: width, height: height)
        case let .windowRelative(corner, dx, dy, width, height):
            guard let anchorWindowFrame else { return nil }
            let origin = WindowAnchor.resolve(
                WindowAnchor.Offset(corner: corner, dx: dx, dy: dy),
                in: anchorWindowFrame
            )
            return CGRect(x: origin.x, y: origin.y, width: width, height: height)
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
