import CoreGraphics
import Foundation

/// Phát sự kiện chuột và ghi nhớ nút nào đang bị giữ.
///
/// Việc ghi nhớ tồn tại vì `SF-1`: Hành động `click` có `holdMilliseconds`, và từ Lát 2 có kéo
/// thả — cả hai đều để lại `mouseDown` chưa có `mouseUp` nếu bị cắt giữa chừng. Khi đó hệ điều
/// hành tin rằng nút chuột đang bị giữ và người dùng mất khả năng thao tác. `releaseAllHeld()`
/// là hàm đồng bộ, không `async`, để gọi được từ `defer` sau khi tác vụ đã bị huỷ (`SF-2`).
@MainActor
final class MouseEventEmitter {
    /// Nơi sự kiện đi tới. Tách ra được để test kiểm chứng `SF-1` mà không thật sự click lên
    /// máy đang chạy test.
    typealias EventSink = @MainActor (CGEvent) -> Void

    private var heldButtons: [MouseButton: CGPoint] = [:]
    private let source = CGEventSource(stateID: .hidSystemState)
    private let sink: EventSink

    init(sink: @escaping EventSink = MouseEventEmitter.postToSystem) {
        self.sink = sink
    }

    /// Phát vào hệ thống để ứng dụng đích xử lý như thao tác thật (EX-19).
    static func postToSystem(_ event: CGEvent) {
        event.post(tap: .cghidEventTap)
    }

    var hasHeldButtons: Bool { !heldButtons.isEmpty }

    func press(_ button: MouseButton, at point: CGPoint, clickState: Int) {
        heldButtons[button] = point
        post(type: button.downEventType, button: button, at: point, clickState: clickState)
    }

    func release(_ button: MouseButton, at point: CGPoint, clickState: Int) {
        heldButtons[button] = nil
        post(type: button.upEventType, button: button, at: point, clickState: clickState)
    }

    func move(to point: CGPoint) {
        post(type: .mouseMoved, button: .left, at: point, clickState: 0)
    }

    /// Cuộn tại `point`. Đơn vị là dòng, `deltaY` dương là cuộn lên.
    func scroll(deltaX: Int, deltaY: Int, at point: CGPoint) {
        guard let event = CGEvent(
            scrollWheelEvent2Source: source,
            units: .line,
            wheelCount: 2,
            wheel1: Int32(deltaY),
            wheel2: Int32(deltaX),
            wheel3: 0
        ) else { return }

        // Sự kiện cuộn đi theo vị trí ghi trong chính nó, nên đặt toạ độ ở đây là đủ; không cần
        // dời con trỏ thật của người dùng.
        event.location = point
        sink(event)
    }

    /// Nhả mọi nút còn đang giữ (SF-1). Gọi được sau khi tác vụ đã bị huỷ (SF-2).
    func releaseAllHeld() {
        let held = heldButtons
        heldButtons.removeAll()
        for (button, point) in held {
            post(type: button.upEventType, button: button, at: point, clickState: 1)
        }
    }

    private func post(
        type: CGEventType,
        button: MouseButton,
        at point: CGPoint,
        clickState: Int
    ) {
        guard let event = CGEvent(
            mouseEventSource: source,
            mouseType: type,
            mouseCursorPosition: point,
            mouseButton: button.cgButton
        ) else { return }

        if clickState > 0 {
            // Thiếu trường này thì AppKit coi n cú click là n thao tác rời rạc chứ không phải
            // một double click (EX-16).
            event.setIntegerValueField(.mouseEventClickState, value: Int64(clickState))
        }
        sink(event)
    }
}

private extension MouseButton {
    var cgButton: CGMouseButton {
        switch self {
        case .left: return .left
        case .right: return .right
        case .center: return .center
        }
    }

    var downEventType: CGEventType {
        switch self {
        case .left: return .leftMouseDown
        case .right: return .rightMouseDown
        case .center: return .otherMouseDown
        }
    }

    var upEventType: CGEventType {
        switch self {
        case .left: return .leftMouseUp
        case .right: return .rightMouseUp
        case .center: return .otherMouseUp
        }
    }
}
