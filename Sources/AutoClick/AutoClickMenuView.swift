import AppKit
import SwiftUI

enum PopoverMode: String, CaseIterable, Identifiable {
    case simple
    case scenario

    var id: String { rawValue }

    var title: String {
        switch self {
        case .simple: return "Đơn giản"
        case .scenario: return "Kịch bản"
        }
    }
}

/// Bề mặt **chạy** (UI-1). Việc sửa Bước nằm ở cửa sổ soạn thảo, không ở đây.
struct AutoClickMenuView: View {
    @ObservedObject var clicker: AutoClicker
    @ObservedObject var runner: ScenarioRunner
    @ObservedObject var store: ScenarioStore
    @ObservedObject var launchAtLogin: LaunchAtLoginManager

    @AppStorage("popoverMode") private var rawMode = PopoverMode.simple.rawValue
    @Environment(\.openWindow) private var openWindow

    private var mode: Binding<PopoverMode> {
        Binding(
            get: { PopoverMode(rawValue: rawMode) ?? .simple },
            set: { rawMode = $0.rawValue }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            Picker("Chế độ", selection: mode) {
                ForEach(PopoverMode.allCases) { Text($0.title).tag($0) }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .disabled(runner.isRunning)

            Group {
                switch mode.wrappedValue {
                case .simple: simpleSection
                case .scenario: scenarioSection
                }
            }
            .disabled(runner.isRunning)

            if let blocker {
                Label(blocker, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Label(runner.statusText, systemImage: statusIcon)
                .font(.callout)
                .foregroundStyle(runner.isRunning ? Color.accentColor : .secondary)

            runButton

            Divider()

            Toggle(
                "Khởi động cùng MacBook",
                isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.setEnabled($0) }
                )
            )

            if let error = launchAtLogin.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Button("Cấp quyền Accessibility") {
                    clicker.openAccessibilitySettings()
                }
                .buttonStyle(.link)

                Spacer()

                Button("Thoát") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
            .font(.caption)
        }
        .padding(16)
        .frame(width: 340)
        .onAppear {
            clicker.refreshRunningApplications()
            store.reload()
        }
    }

    // MARK: - Bắt đầu / Dừng

    private var blocker: String? {
        if runner.isRunning { return nil }
        switch mode.wrappedValue {
        case .simple:
            return clicker.validationMessage ?? clicker.message
        case .scenario:
            guard let scenario = store.selectedScenario else { return "Chưa có kịch bản nào." }
            if store.isReadOnly(scenario) { return "Kịch bản này chỉ xem được." }
            return runner.validate(scenario)?.errorDescription
        }
    }

    private var canRun: Bool {
        switch mode.wrappedValue {
        case .simple:
            return clicker.validationMessage == nil
        case .scenario:
            guard let scenario = store.selectedScenario else { return false }
            return !store.isReadOnly(scenario) && runner.validate(scenario) == nil
        }
    }

    @ViewBuilder
    private var runButton: some View {
        if runner.isRunning {
            Button("Dừng", role: .destructive) {
                runner.stop()
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .keyboardShortcut("s", modifiers: [.command, .option])
        } else {
            Button {
                let started: Bool
                switch mode.wrappedValue {
                case .simple:
                    started = clicker.start()
                case .scenario:
                    started = store.selectedScenario.map { runner.start($0) } ?? false
                }
                if started { NSApp.keyWindow?.orderOut(nil) }
            } label: {
                Label("Bắt đầu sau \(runner.countdownSeconds) giây", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canRun)
        }
    }

    // MARK: - Kịch bản

    private var scenarioSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Picker("Kịch bản", selection: $store.selectedScenarioID) {
                    if store.scenarios.isEmpty {
                        Text("Chưa có kịch bản").tag(UUID?.none)
                    }
                    ForEach(store.scenarios) { scenario in
                        Text(scenario.name).tag(UUID?.some(scenario.id))
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)

                Button {
                    openEditor()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .help("Soạn kịch bản")
            }

            if let scenario = store.selectedScenario {
                Label(summary(of: scenario), systemImage: "list.number")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("Soạn kịch bản…") { openEditor() }
                .buttonStyle(.link)
                .font(.caption)
        }
    }

    private func summary(of scenario: Scenario) -> String {
        let steps = "\(scenario.steps.count) bước"
        switch scenario.runCount {
        case let .times(count) where count > 1:
            return "\(steps) · lặp \(count) vòng"
        case .untilStopped:
            return "\(steps) · lặp đến khi dừng"
        case .times:
            return steps
        }
    }

    private func openEditor() {
        // App là agent (LSUIElement) nên cửa sổ mở ra sẽ không nhận bàn phím nếu thiếu dòng này (UI-3).
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: ScenarioEditorScene.windowID)
    }

    // MARK: - Chế độ đơn giản

    private var simpleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 10) {
                numberField(title: "Time interval", suffix: "ms", text: $clicker.intervalText)
                numberField(title: "Repeat", suffix: "lần", text: $clicker.repeatText)
            }

            targetPicker
            applicationLockPicker
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "cursorarrow.click.2")
                .font(.title2)
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("Auto Click")
                    .font(.headline)
                Text("Click theo con trỏ, điểm cố định, hoặc kịch bản")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var targetPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Vị trí click")
                .font(.subheadline.weight(.medium))

            Picker("Vị trí click", selection: $clicker.targetMode) {
                Text("Theo con trỏ").tag(ClickTargetMode.cursor)
                Text("Điểm cố định").tag(ClickTargetMode.fixedPoint)
            }
            .labelsHidden()
            .pickerStyle(.segmented)

            if clicker.targetMode == .fixedPoint {
                HStack {
                    Label(clicker.fixedPointDescription, systemImage: "scope")
                        .font(.caption)
                        .foregroundStyle(clicker.fixedPoint == nil ? .secondary : .primary)

                    Spacer()

                    Button(clicker.fixedPoint == nil ? "Chọn điểm…" : "Chọn lại…") {
                        let returnWindow = NSApp.keyWindow
                        returnWindow?.orderOut(nil)
                        clicker.chooseFixedPoint(returningTo: returnWindow)
                    }
                }
            } else {
                Label("Lấy vị trí con trỏ khi hết đếm ngược", systemImage: "cursorarrow")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusIcon: String {
        if runner.countdown != nil { return "timer" }
        if runner.isRunning { return "cursorarrow.rays" }
        return "checkmark.circle"
    }

    private var applicationLockPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Chỉ click trong ứng dụng", isOn: $clicker.applicationLockEnabled)
                .font(.subheadline.weight(.medium))

            if clicker.applicationLockEnabled {
                HStack {
                    Picker("Ứng dụng", selection: $clicker.selectedApplicationIdentifier) {
                        Text("Chọn ứng dụng…").tag("")

                        if !clicker.selectedApplicationIdentifier.isEmpty,
                           !clicker.runningApplications.contains(where: {
                               $0.bundleIdentifier == clicker.selectedApplicationIdentifier
                           }) {
                            Text("\(clicker.selectedApplicationName) — đã đóng")
                                .tag(clicker.selectedApplicationIdentifier)
                        }

                        ForEach(clicker.runningApplications) { application in
                            Text(application.name).tag(application.bundleIdentifier)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity)

                    Button {
                        clicker.refreshRunningApplications()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Làm mới danh sách ứng dụng")
                }

                Label("Chỉ click khi điểm thuộc ứng dụng đã chọn", systemImage: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func numberField(
        title: String,
        suffix: String,
        text: Binding<String>
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("", text: text)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 110)
            Text(suffix)
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .leading)
        }
    }
}
