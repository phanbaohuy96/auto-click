import AppKit
import SwiftUI

struct AutoClickMenuView: View {
    @ObservedObject var clicker: AutoClicker
    @ObservedObject var launchAtLogin: LaunchAtLoginManager

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            VStack(spacing: 10) {
                numberField(
                    title: "Time interval",
                    suffix: "ms",
                    text: $clicker.intervalText
                )
                numberField(
                    title: "Repeat",
                    suffix: "lần",
                    text: $clicker.repeatText
                )
            }
            .disabled(clicker.isRunning)

            targetPicker
                .disabled(clicker.isRunning)

            applicationLockPicker
                .disabled(clicker.isRunning)

            if let validationMessage = clicker.validationMessage {
                Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Label(clicker.statusText, systemImage: statusIcon)
                .font(.callout)
                .foregroundStyle(clicker.isRunning ? Color.accentColor : .secondary)

            if clicker.isRunning {
                Button("Dừng", role: .destructive) {
                    clicker.stop()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .keyboardShortcut("s", modifiers: [.command, .option])
            } else {
                Button {
                    if clicker.start() {
                        NSApp.keyWindow?.orderOut(nil)
                    }
                } label: {
                    Label("Bắt đầu sau 3 giây", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(clicker.validationMessage != nil)
            }

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
                Text("Click theo con trỏ hoặc điểm cố định")
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
        if clicker.countdown != nil { return "timer" }
        if clicker.isRunning { return "cursorarrow.rays" }
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

                Label(
                    "Chỉ click khi điểm thuộc ứng dụng đã chọn",
                    systemImage: "lock.fill"
                )
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
