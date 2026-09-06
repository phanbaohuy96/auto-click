import AppKit
import Carbon.HIToolbox
import SwiftUI

@MainActor
final class AutoClickRuntimeController: ObservableObject {
    private let runner: ScenarioRunner
    private let activityPanel: RunningActivityPanelController
    private var hotKey: EventHotKeyRef?
    private var hotKeyHandler: EventHandlerRef?

    init(runner: ScenarioRunner) {
        self.runner = runner
        activityPanel = RunningActivityPanelController(runner: runner)

        runner.onRunningStateChanged = { [weak self] isRunning in
            self?.activityPanel.setVisible(isRunning)
        }

        registerStopHotKey()
    }

    private func stopFromShortcut() {
        guard runner.isRunning else { return }
        runner.stop()
    }

    private func registerStopHotKey() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let context = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, context in
                guard let context else { return OSStatus(eventNotHandledErr) }
                let controller = Unmanaged<AutoClickRuntimeController>
                    .fromOpaque(context)
                    .takeUnretainedValue()
                Task { @MainActor in
                    controller.stopFromShortcut()
                }
                return noErr
            },
            1,
            &eventType,
            context,
            &hotKeyHandler
        )

        let identifier = EventHotKeyID(
            signature: OSType(0x4154_434B), // "ATCK"
            id: 1
        )
        RegisterEventHotKey(
            UInt32(kVK_ANSI_S),
            UInt32(cmdKey | optionKey),
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotKey
        )
    }
}

@MainActor
private final class RunningActivityPanelController {
    private let panel: NSPanel

    init(runner: ScenarioRunner) {
        let panelSize = NSSize(width: 390, height: 86)
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.contentView = NSHostingView(rootView: RunningActivityView(runner: runner))
    }

    func setVisible(_ isVisible: Bool) {
        if isVisible {
            positionNearTopCenter()
            panel.orderFrontRegardless()
        } else {
            panel.orderOut(nil)
        }
    }

    private func positionNearTopCenter() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let visibleFrame = screen.visibleFrame
        let origin = NSPoint(
            x: visibleFrame.midX - panel.frame.width / 2,
            y: visibleFrame.maxY - panel.frame.height - 12
        )
        panel.setFrameOrigin(origin)
    }
}

private struct RunningActivityView: View {
    @ObservedObject var runner: ScenarioRunner

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: runner.countdown == nil ? "cursorarrow.rays" : "timer")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(runner.runningScenarioName ?? "Auto Click")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(runner.statusText)
                    .font(.headline)
                    .lineLimit(1)
                // Lối thoát duy nhất khi chuỗi click đang cướp con trỏ (UI-15).
                Text("Dừng nhanh bằng ⌥⌘S")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button {
                runner.stop()
            } label: {
                Label("Dừng", systemImage: "stop.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .keyboardShortcut("s", modifiers: [.command, .option])
        }
        .padding(.horizontal, 16)
        .frame(width: 390, height: 86)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.16))
        }
    }
}
