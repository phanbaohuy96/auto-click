import AppKit
import SwiftUI

enum PopoverMode: String, CaseIterable, Identifiable {
    case simple
    case scenario

    var id: String { rawValue }

    var titleKey: StringKey {
        switch self {
        case .simple: return .menuModeSimple
        case .scenario: return .menuModeScenario
        }
    }
}

/// The **running** surface (UI-1). Editing Steps lives in the editor window, not here.
struct AutoClickMenuView: View {
    @ObservedObject var clicker: AutoClicker
    @ObservedObject var runner: ScenarioRunner
    @ObservedObject var store: ScenarioStore
    @ObservedObject var recorder: ScenarioRecorder
    @ObservedObject var launchAtLogin: LaunchAtLoginManager
    @ObservedObject var localization: Localization
    let onOpenEditor: () -> Void

    @AppStorage("popoverMode") private var rawMode = PopoverMode.simple.rawValue

    private var mode: Binding<PopoverMode> {
        Binding(
            get: { PopoverMode(rawValue: rawMode) ?? .simple },
            set: { rawMode = $0.rawValue }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            Picker(localization(.menuModeLabel), selection: mode) {
                ForEach(PopoverMode.allCases) { Text(localization($0.titleKey)).tag($0) }
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
                Label(
                    blocker.text,
                    systemImage: blocker.needsAttention
                        ? "exclamationmark.triangle.fill"
                        : "checkmark.circle"
                )
                .font(.caption)
                .foregroundStyle(blocker.needsAttention ? Color.orange : Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            Label(runner.statusText, systemImage: statusIcon)
                .font(.callout)
                .foregroundStyle(statusColour)
                // UI-16: a truncated error message makes the cause impossible to track down.
                .fixedSize(horizontal: false, vertical: true)

            runButton
            recordButton

            Divider()

            Toggle(
                localization(.menuLaunchAtLogin),
                isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.setEnabled($0) }
                )
            )

            // UI-22: the popover's settings area, next to the login toggle that opened it. The editor window
            // is the wrong home — someone who only ever uses Simple mode never opens it, and would have no
            // way to find the language at all.
            Picker(
                localization(.menuLanguage),
                selection: Binding(
                    get: { localization.preference },
                    set: { localization.select($0) }
                )
            ) {
                Text(localization(.menuLanguageFollowSystem)).tag(String?.none)
                ForEach(Localization.supportedCodes, id: \.self) { code in
                    Text(Localization.nativeName(of: code)).tag(String?.some(code))
                }
            }
            // `.menu`, not `.segmented` like the pickers above: six entries mixing Han characters with Latin
            // would not fit a popover fixed at 340 points.
            .pickerStyle(.menu)

            if let error = launchAtLogin.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Button(localization(.menuGrantAccessibility)) {
                    clicker.openAccessibilitySettings()
                }
                .buttonStyle(.link)

                if needsScreenRecording {
                    Button(localization(.menuGrantScreenRecording)) {
                        ScreenRecordingPermission.request()
                        ScreenRecordingPermission.openSettings()
                    }
                    .buttonStyle(.link)
                }

                Spacer()

                Button(localization(.menuQuit)) {
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

    // MARK: - Start / Stop

    /// The line below the configuration. Mostly reasons a Scenario cannot run, but **not always**:
    /// the recorder reports success through it too, and a success line must not carry the error icon.
    private struct Notice {
        let text: String
        let needsAttention: Bool
    }

    private var blocker: Notice? {
        if runner.isRunning { return nil }
        switch mode.wrappedValue {
        case .simple:
            guard let text = clicker.validationMessage ?? clicker.messageText else { return nil }
            return Notice(text: text, needsAttention: true)
        case .scenario:
            guard let scenario = store.selectedScenario else {
                return Notice(text: localization(.scenarioNoneAtAll), needsAttention: true)
            }
            if store.isReadOnly(scenario) {
                return Notice(text: localization(.scenarioReadOnlyBlocker), needsAttention: true)
            }
            if needsScreenRecording {
                return Notice(
                    text: localization(.scenarioNeedsScreenRecording),
                    needsAttention: true
                )
            }
            if let invalid = runner.validate(scenario)?.errorDescription {
                return Notice(text: invalid, needsAttention: true)
            }
            guard let recorderMessage = recorder.message else { return nil }
            return Notice(text: recorderMessage.text, needsAttention: recorderMessage.needsAttention)
        }
    }

    /// Only ask for the second permission when the Scenario actually uses recognition (SF-5).
    private var needsScreenRecording: Bool {
        guard let scenario = store.selectedScenario else { return false }
        let usesRecognition = scenario.steps
            .flatMap(\.targets)
            .contains { $0.recognitionSettings != nil }
        return usesRecognition && !ScreenRecordingPermission.isGranted
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
            Button(localization(.runStop), role: .destructive) {
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
                    if let scenario = store.selectedScenario {
                        runner.templatesDirectory = store.templatesDirectory(for: scenario.id)
                        started = runner.start(scenario)
                    } else {
                        started = false
                    }
                }
                if started { NSApp.keyWindow?.orderOut(nil) }
            } label: {
                Label(localization(.runStart, runner.countdownSeconds), systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canRun)
        }
    }

    /// RC-1: a Recording session starts and ends with the global shortcut, not with a button — clicking a button
    /// would land in the recording itself. The button here only starts it; finishing needs ⌥⌘R.
    @ViewBuilder
    private var recordButton: some View {
        if recorder.isRecording {
            Label(
                localization(.recordInProgress, recorder.recordedGestureCount),
                systemImage: "record.circle"
            )
                .font(.caption)
                .foregroundStyle(.red)
        } else if !runner.isRunning {
            HStack(spacing: 8) {
                Button {
                    NSApp.keyWindow?.orderOut(nil)
                    recorder.start()
                } label: {
                    Label(localization(.recordButton), systemImage: "record.circle")
                }
                Text(localization(.recordHint))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Scenario

    private var scenarioSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Picker(localization(.scenarioPickerLabel), selection: $store.selectedScenarioID) {
                    if store.scenarios.isEmpty {
                        Text(localization(.scenarioPickerEmpty)).tag(UUID?.none)
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
                .help(localization(.scenarioOpenEditor))
            }

            if let scenario = store.selectedScenario {
                Label(summary(of: scenario), systemImage: "list.number")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button(localization(.scenarioOpenEditorEllipsis)) { openEditor() }
                .buttonStyle(.link)
                .font(.caption)
        }
    }

    private func summary(of scenario: Scenario) -> String {
        let steps = localization(.scenarioSummarySteps, scenario.steps.count)
        switch scenario.runCount {
        case let .times(count) where count > 1:
            return localization(.scenarioSummaryWithLoops, steps, localization(.scenarioSummaryLoops, count))
        case .untilStopped:
            return localization(.scenarioSummaryUntilStopped, steps)
        case .times:
            return steps
        }
    }

    private func openEditor() { onOpenEditor() }

    // MARK: - Simple mode

    private var simpleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 10) {
                numberField(
                    title: localization(.simpleInterval),
                    suffix: "ms",
                    text: $clicker.intervalText
                )
                numberField(
                    title: localization(.simpleRepeat),
                    suffix: localization(.simpleRepeatUnit),
                    text: $clicker.repeatText
                )
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
                Text(localization(.menuSubtitle))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var targetPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localization(.simplePositionLabel))
                .font(.subheadline.weight(.medium))

            Picker(localization(.simplePositionLabel), selection: $clicker.targetMode) {
                Text(localization(.simplePositionCursor)).tag(ClickTargetMode.cursor)
                Text(localization(.simplePositionFixed)).tag(ClickTargetMode.fixedPoint)
            }
            .labelsHidden()
            .pickerStyle(.segmented)

            if clicker.targetMode == .fixedPoint {
                HStack {
                    Label(clicker.fixedPointDescription, systemImage: "scope")
                        .font(.caption)
                        .foregroundStyle(clicker.fixedPoint == nil ? .secondary : .primary)

                    Spacer()

                    Button(localization(
                        clicker.fixedPoint == nil ? .simplePointChoose : .simplePointChooseAgain
                    )) {
                        let returnWindow = NSApp.keyWindow
                        returnWindow?.orderOut(nil)
                        clicker.chooseFixedPoint(returningTo: returnWindow)
                    }
                }
            } else {
                Label(localization(.simpleCursorHint), systemImage: "cursorarrow")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusIcon: String {
        if runner.countdown != nil { return "timer" }
        if runner.isRunning { return "cursorarrow.rays" }
        // UI-16: an error state has to look like an error. Previously every non-running state carried a
        // checkmark, so the line "Error: …" appeared with the success icon.
        if runner.messageIsError { return "exclamationmark.triangle.fill" }
        return "checkmark.circle"
    }

    private var statusColour: Color {
        if runner.isRunning { return .accentColor }
        return runner.messageIsError ? .orange : .secondary
    }

    private var applicationLockPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(localization(.simpleLockToggle), isOn: $clicker.applicationLockEnabled)
                .font(.subheadline.weight(.medium))

            if clicker.applicationLockEnabled {
                HStack {
                    Picker(
                        localization(.simpleLockApplication),
                        selection: $clicker.selectedApplicationIdentifier
                    ) {
                        Text(localization(.simpleLockChoose)).tag("")

                        if !clicker.selectedApplicationIdentifier.isEmpty,
                           !clicker.runningApplications.contains(where: {
                               $0.bundleIdentifier == clicker.selectedApplicationIdentifier
                           }) {
                            Text(localization(.simpleLockClosed, clicker.selectedApplicationDisplayName))
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
                    .help(localization(.simpleLockRefresh))
                }

                Label(localization(.simpleLockHint), systemImage: "lock.fill")
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
