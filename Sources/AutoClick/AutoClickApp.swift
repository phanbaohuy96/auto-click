import SwiftUI

@main
struct AutoClickApp: App {
    @StateObject private var runner: ScenarioRunner
    @StateObject private var store: ScenarioStore
    @StateObject private var recorder: ScenarioRecorder
    @StateObject private var clicker: AutoClicker
    @StateObject private var launchAtLogin: LaunchAtLoginManager
    @StateObject private var runtimeController: AutoClickRuntimeController
    @StateObject private var editorController: ScenarioEditorWindowController

    init() {
        let runner = ScenarioRunner()
        let store = ScenarioStore()
        let recorder = ScenarioRecorder()
        let editorController = ScenarioEditorWindowController(store: store, runner: runner)

        // RC-16: ghi xong thì lưu Kịch bản, chọn nó, rồi mở cửa sổ soạn thảo.
        recorder.onFinished = { result in
            store.addRecorded(result.scenario)
            editorController.show()
        }

        _runner = StateObject(wrappedValue: runner)
        _store = StateObject(wrappedValue: store)
        _recorder = StateObject(wrappedValue: recorder)
        _clicker = StateObject(wrappedValue: AutoClicker(runner: runner))
        _launchAtLogin = StateObject(wrappedValue: LaunchAtLoginManager())
        _runtimeController = StateObject(
            wrappedValue: AutoClickRuntimeController(runner: runner, recorder: recorder)
        )
        _editorController = StateObject(wrappedValue: editorController)
    }

    var body: some Scene {
        MenuBarExtra {
            AutoClickMenuView(
                clicker: clicker,
                runner: runner,
                store: store,
                recorder: recorder,
                launchAtLogin: launchAtLogin,
                onOpenEditor: { editorController.show() }
            )
        } label: {
            Label(menuBarTitle, systemImage: menuBarIcon)
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarTitle: String {
        if recorder.isRecording { return "Auto Click đang ghi — ⌥⌘R để kết thúc" }
        if runner.isRunning { return "Auto Click đang chạy — ⌥⌘S để dừng" }
        return "Auto Click"
    }

    private var menuBarIcon: String {
        if recorder.isRecording { return "record.circle" }
        return runner.isRunning ? "stop.circle.fill" : "cursorarrow.click"
    }
}
