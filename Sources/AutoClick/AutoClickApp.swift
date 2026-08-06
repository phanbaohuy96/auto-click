import SwiftUI

@main
struct AutoClickApp: App {
    @StateObject private var clicker: AutoClicker
    @StateObject private var launchAtLogin: LaunchAtLoginManager
    @StateObject private var runtimeController: AutoClickRuntimeController

    init() {
        let clicker = AutoClicker()
        _clicker = StateObject(wrappedValue: clicker)
        _launchAtLogin = StateObject(wrappedValue: LaunchAtLoginManager())
        _runtimeController = StateObject(
            wrappedValue: AutoClickRuntimeController(clicker: clicker)
        )
    }

    var body: some Scene {
        MenuBarExtra {
            AutoClickMenuView(
                clicker: clicker,
                launchAtLogin: launchAtLogin
            )
        } label: {
            Label(
                clicker.isRunning ? "Auto Click đang chạy — ⌥⌘S để dừng" : "Auto Click",
                systemImage: clicker.isRunning ? "stop.circle.fill" : "cursorarrow.click"
            )
        }
        .menuBarExtraStyle(.window)
    }
}
