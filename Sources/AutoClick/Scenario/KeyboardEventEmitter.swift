import CoreGraphics
import Foundation

/// Phát sự kiện bàn phím (EX-21, EX-22).
///
/// Không có sổ ghi nút đang giữ như `MouseEventEmitter`: phím bổ trợ được gắn thẳng vào cờ của
/// từng sự kiện chứ không phát riêng, nên huỷ giữa chừng không để lại phím nào bị kẹt.
@MainActor
final class KeyboardEventEmitter {
    typealias EventSink = @MainActor (CGEvent) -> Void

    private let source = CGEventSource(stateID: .hidSystemState)
    private let sink: EventSink

    init(sink: @escaping EventSink = KeyboardEventEmitter.postToSystem) {
        self.sink = sink
    }

    static func postToSystem(_ event: CGEvent) {
        event.post(tap: .cghidEventTap)
    }

    /// Gõ một chuỗi ký tự bất kỳ.
    ///
    /// Dùng `keyboardSetUnicodeString` thay vì tra mã phím, nên không phụ thuộc bố cục bàn phím
    /// và gõ được cả tiếng Việt lẫn emoji — điều mà cách map keycode không làm được.
    func type(_ text: String) {
        guard !text.isEmpty else { return }
        for character in text {
            let utf16 = Array(String(character).utf16)
            for isKeyDown in [true, false] {
                guard let event = CGEvent(
                    keyboardEventSource: source,
                    virtualKey: 0,
                    keyDown: isKeyDown
                ) else { continue }
                event.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
                sink(event)
            }
        }
    }

    /// Nhấn một tổ hợp phím. Trả về `false` nếu không nhận ra tên phím.
    @discardableResult
    func press(_ stroke: KeyStroke) -> Bool {
        guard let keyCode = KeyCatalog.keyCode(for: stroke.key) else { return false }
        let flags = stroke.modifiers.eventFlags

        for isKeyDown in [true, false] {
            guard let event = CGEvent(
                keyboardEventSource: source,
                virtualKey: keyCode,
                keyDown: isKeyDown
            ) else { continue }
            event.flags = flags
            sink(event)
        }
        return true
    }
}
