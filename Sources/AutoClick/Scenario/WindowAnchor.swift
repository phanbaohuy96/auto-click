import ApplicationServices
import CoreGraphics
import Foundation

/// Neo một điểm vào **Cửa sổ neo** (DM-13, EX-7).
///
/// Góc bám được chọn tự động lúc ghi điểm — góc gần điểm nhất — chứ không phải luôn là góc
/// trên-trái. Nhờ vậy nút ở góc phải-dưới vẫn đúng khi người dùng phóng to cửa sổ; neo cố định
/// vào góc trên-trái thì điểm đó sẽ trôi vào giữa màn hình.
///
/// Mọi toạ độ ở đây nằm trong không gian của `CGEvent`: gốc ở góc trên-trái, đơn vị point.
/// Accessibility dùng đúng không gian đó nên không cần quy đổi.
enum WindowAnchor {
    struct Offset: Equatable, Sendable {
        var corner: WindowCorner
        var dx: Double
        var dy: Double
    }

    /// Toạ độ của một góc cửa sổ.
    static func cornerPoint(_ corner: WindowCorner, in frame: CGRect) -> CGPoint {
        switch corner {
        case .topLeft: return CGPoint(x: frame.minX, y: frame.minY)
        case .topRight: return CGPoint(x: frame.maxX, y: frame.minY)
        case .bottomLeft: return CGPoint(x: frame.minX, y: frame.maxY)
        case .bottomRight: return CGPoint(x: frame.maxX, y: frame.maxY)
        }
    }

    /// Chọn góc gần `point` nhất và trả về độ lệch so với chính góc đó.
    static func offset(for point: CGPoint, in frame: CGRect) -> Offset {
        let nearest = WindowCorner.allCases.min { lhs, rhs in
            squaredDistance(from: point, to: cornerPoint(lhs, in: frame))
                < squaredDistance(from: point, to: cornerPoint(rhs, in: frame))
        } ?? .topLeft

        let origin = cornerPoint(nearest, in: frame)
        return Offset(corner: nearest, dx: point.x - origin.x, dy: point.y - origin.y)
    }

    /// Giải một độ lệch trở lại thành toạ độ thật.
    static func resolve(_ offset: Offset, in frame: CGRect) -> CGPoint {
        let origin = cornerPoint(offset.corner, in: frame)
        return CGPoint(x: origin.x + offset.dx, y: origin.y + offset.dy)
    }

    private static func squaredDistance(from lhs: CGPoint, to rhs: CGPoint) -> Double {
        let dx = lhs.x - rhs.x
        let dy = lhs.y - rhs.y
        return dx * dx + dy * dy
    }

    /// Khung của cửa sổ trước nhất thuộc tiến trình đã cho.
    ///
    /// Ưu tiên `AXFocusedWindow`; nếu ứng dụng không khai báo cửa sổ nào đang focus thì lấy cửa
    /// sổ đầu trong danh sách, vốn là cửa sổ trên cùng.
    static func focusedWindowFrame(ofProcess processIdentifier: pid_t) -> CGRect? {
        let application = AXUIElementCreateApplication(processIdentifier)
        guard let window = copyElement(application, attribute: kAXFocusedWindowAttribute)
            ?? firstWindow(of: application) else { return nil }

        guard let position = copyPoint(window, attribute: kAXPositionAttribute),
              let size = copySize(window, attribute: kAXSizeAttribute) else { return nil }
        return CGRect(origin: position, size: size)
    }

    private static func firstWindow(of application: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            application,
            kAXWindowsAttribute as CFString,
            &value
        ) == .success else { return nil }
        return (value as? [AXUIElement])?.first
    }

    private static func copyElement(_ element: AXUIElement, attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value else { return nil }
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private static func copyPoint(_ element: AXUIElement, attribute: String) -> CGPoint? {
        guard let value = copyAXValue(element, attribute: attribute) else { return nil }
        var point = CGPoint.zero
        guard AXValueGetValue(value, .cgPoint, &point) else { return nil }
        return point
    }

    private static func copySize(_ element: AXUIElement, attribute: String) -> CGSize? {
        guard let value = copyAXValue(element, attribute: attribute) else { return nil }
        var size = CGSize.zero
        guard AXValueGetValue(value, .cgSize, &size) else { return nil }
        return size
    }

    private static func copyAXValue(_ element: AXUIElement, attribute: String) -> AXValue? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        return (value as! AXValue)
    }
}
