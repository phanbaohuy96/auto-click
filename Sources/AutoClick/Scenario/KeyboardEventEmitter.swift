import CoreGraphics
import Foundation

/// Emits keyboard events (EX-21, EX-22).
///
/// There is no held-key ledger like `MouseEventEmitter`'s: modifiers are attached straight to each event's flags
/// rather than emitted separately, so cancelling part-way leaves no key stuck down.
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

    /// Types an arbitrary string.
    ///
    /// Uses `keyboardSetUnicodeString` rather than looking up key codes, so it does not depend on the keyboard
    /// layout and can type Vietnamese and emoji alike — which a keycode mapping cannot.
    ///
    /// EX-24: the string is split into **chunks**, one key pair per chunk — not one pair per character. Measured
    /// on a real machine: sending one character at a time worked only about 1 time in 5 with a long string,
    /// because the Unicode payload is occasionally lost and the system falls back to `virtualKey` (0 = the `a`
    /// key), inserting an `a` instead of the real character **with no error at all**. Chunking cuts the event
    /// count by 20× and raises the success rate to ~94%. Still not 100% — the remaining limit is stated in `EX-24`.
    func type(_ text: String) async throws {
        let units = Array(text.utf16)
        guard !units.isEmpty else { return }

        var index = 0
        while index < units.count {
            var end = min(index + ScenarioLimits.typingChunkUTF16Units, units.count)
            // Never cut inside a surrogate pair, otherwise an emoji breaks into two pieces of garbage.
            if end < units.count, end - 1 > index, UTF16.isLeadSurrogate(units[end - 1]) {
                end -= 1
            }
            let chunk = Array(units[index..<end])

            // The text is attached to `keyDown` only; key-up carries no characters, just like real typing.
            if let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) {
                down.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: chunk)
                sink(down)
            }
            // Key-up carries no text. The character of `virtualKey` cannot be removed from it — it still reads
            // as `a` — but applications only insert text on key-down, so it does no harm. Switching to a key
            // code that produces no character (F13, fn) was measured to type **nothing at all**, so 0 is
            // mandatory rather than a choice.
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

    /// Presses a key combination. Returns `false` if the key name is not recognised.
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
