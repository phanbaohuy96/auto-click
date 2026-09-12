import AppKit
import SwiftUI

/// Owns the editor window (UI-2).
///
/// SwiftUI's `Window` scene is not used because `openWindow` can only be called from inside a view that is on
/// screen, whereas a **Recording session** ends once the popover has closed (RC-16).
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
        // The app is an agent (LSUIElement), so without this line the window opens but takes no keyboard input (UI-3).
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
