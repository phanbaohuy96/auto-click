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
    ///
    /// EX-24: chuỗi được cắt thành **khối**, mỗi khối một cặp phím — không phải mỗi ký tự một
    /// cặp. Đo trên máy thật: gửi từng ký tự chỉ đúng ~1/5 lần với chuỗi dài, vì payload Unicode
    /// thỉnh thoảng bị mất và hệ thống rơi về `virtualKey` (số 0 = phím `a`), chèn ra chữ `a`
    /// thay cho chữ thật mà **không báo lỗi gì**. Cắt khối giảm số sự kiện đi 20 lần và nâng tỉ
    /// lệ đúng lên ~94%. Vẫn chưa phải 100% — giới hạn còn lại được nói rõ ở `EX-24`.
    func type(_ text: String) async throws {
        let units = Array(text.utf16)
        guard !units.isEmpty else { return }

        var index = 0
        while index < units.count {
            var end = min(index + ScenarioLimits.typingChunkUTF16Units, units.count)
            // Không cắt giữa một cặp thay thế, nếu không emoji vỡ thành hai ký tự rác.
            if end < units.count, end - 1 > index, UTF16.isLeadSurrogate(units[end - 1]) {
                end -= 1
            }
            let chunk = Array(units[index..<end])

            // Chuỗi chỉ gắn vào `keyDown`; phím nhả không mang chữ, đúng như gõ thật.
            if let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) {
                down.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: chunk)
                sink(down)
            }
            // Phím nhả không mang chữ. Không xoá được ký tự của `virtualKey` khỏi nó — đọc ra
            // vẫn là `a` — nhưng ứng dụng chỉ chèn chữ ở phím nhấn nên không sao. Đổi sang mã
            // phím không-sinh-chữ (F13, fn) thì đo được là **không gõ ra gì cả**, nên số 0 là
            // bắt buộc chứ không phải lựa chọn.
            if let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
                sink(up)
            }

            index = end
            if index < units.count {
                try await Task.sleep(
                    for: .milliseconds(ScenarioLimits.minimumEventGapMilliseconds)
                )
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
