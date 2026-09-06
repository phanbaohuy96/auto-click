import AppKit
import SwiftUI

/// Sở hữu cửa sổ soạn thảo (UI-2).
///
/// Không dùng `Window` scene của SwiftUI vì `openWindow` chỉ gọi được từ trong một view đang
/// hiển thị, mà **Phiên ghi** kết thúc lúc popover đã đóng (RC-16).
@MainActor
final class ScenarioEditorWindowController: ObservableObject {
    private var window: NSWindow?
    private let store: ScenarioStore
    private let runner: ScenarioRunner

    init(store: ScenarioStore, runner: ScenarioRunner) {
        self.store = store
        self.runner = runner
    }

    func show() {
        // App là agent (LSUIElement) nên cửa sổ mở ra sẽ không nhận bàn phím nếu thiếu dòng này (UI-3).
        NSApp.activate(ignoringOtherApps: true)

        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 860, height: 560),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Soạn kịch bản"
            window.isReleasedWhenClosed = false
            window.center()
            window.contentView = NSHostingView(
                rootView: ScenarioEditorView(store: store, runner: runner)
            )
            self.window = window
        }

        window?.makeKeyAndOrderFront(nil)
    }
}
