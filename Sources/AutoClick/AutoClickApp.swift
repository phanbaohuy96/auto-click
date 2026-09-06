import SwiftUI

@main
struct AutoClickApp: App {
    @StateObject private var runner: ScenarioRunner
    @StateObject private var store: ScenarioStore
    @StateObject private var clicker: AutoClicker
    @StateObject private var launchAtLogin: LaunchAtLoginManager
    @StateObject private var runtimeController: AutoClickRuntimeController

    init() {
        let runner = ScenarioRunner()
        _runner = StateObject(wrappedValue: runner)
        _store = StateObject(wrappedValue: ScenarioStore())
        _clicker = StateObject(wrappedValue: AutoClicker(runner: runner))
        _launchAtLogin = StateObject(wrappedValue: LaunchAtLoginManager())
        _runtimeController = StateObject(
            wrappedValue: AutoClickRuntimeController(runner: runner)
        )
    }

    var body: some Scene {
        MenuBarExtra {
            AutoClickMenuView(
                clicker: clicker,
                runner: runner,
                store: store,
                launchAtLogin: launchAtLogin
            )
        } label: {
            Label(
                runner.isRunning ? "Auto Click đang chạy — ⌥⌘S để dừng" : "Auto Click",
                systemImage: runner.isRunning ? "stop.circle.fill" : "cursorarrow.click"
            )
        }
        .menuBarExtraStyle(.window)

        Window("Soạn kịch bản", id: ScenarioEditorScene.windowID) {
            ScenarioEditorView(store: store, runner: runner)
        }
        .defaultSize(width: 820, height: 520)
    }
}
