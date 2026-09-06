import AppKit
import Foundation

/// Trạng thái biểu mẫu của **Chế độ đơn giản**.
///
/// Đây không phải một bộ chạy. Bấm Bắt đầu ở đây dựng ra một Kịch bản một bước rồi giao cho
/// `ScenarioRunner` — cùng bộ chạy mà cửa sổ soạn thảo dùng (ADR-0002, UI-6). Kịch bản đó là
/// vật thể tạm và không được lưu ra đĩa (UI-7).
@MainActor
final class AutoClicker: ObservableObject {
    @Published var intervalText: String {
        didSet { saveValidSettings() }
    }

    @Published var repeatText: String {
        didSet { saveValidSettings() }
    }

    @Published var targetMode: ClickTargetMode {
        didSet { defaults.set(targetMode.rawValue, forKey: "targetMode") }
    }

    @Published var applicationLockEnabled: Bool {
        didSet { defaults.set(applicationLockEnabled, forKey: "applicationLockEnabled") }
    }

    @Published var selectedApplicationIdentifier: String {
        didSet { saveSelectedApplication() }
    }

    @Published private(set) var fixedPoint: CGPoint?
    @Published private(set) var selectedApplicationName: String
    @Published private(set) var runningApplications: [RunningApplicationOption] = []
    /// Phản hồi cho thao tác chọn điểm. Trạng thái *khi chạy* nằm ở `ScenarioRunner`.
    @Published private(set) var message: String?

    private var pointSelector: ClickPointSelector?
    private let defaults: UserDefaults
    private let runner: ScenarioRunner

    init(runner: ScenarioRunner, defaults: UserDefaults = .standard) {
        self.runner = runner
        self.defaults = defaults
        let interval = defaults.object(forKey: "intervalMilliseconds") as? Int ?? 100
        let repeatCount = defaults.object(forKey: "repeatCount") as? Int ?? 10
        let storedMode = defaults.string(forKey: "targetMode")
            .flatMap(ClickTargetMode.init(rawValue:)) ?? .cursor

        intervalText = String(interval)
        repeatText = String(repeatCount)
        targetMode = storedMode
        applicationLockEnabled = defaults.bool(forKey: "applicationLockEnabled")
        selectedApplicationIdentifier = defaults.string(forKey: "selectedApplicationIdentifier") ?? ""
        selectedApplicationName = defaults.string(forKey: "selectedApplicationName") ?? "Ứng dụng đã chọn"

        if defaults.object(forKey: "fixedPointX") != nil,
           defaults.object(forKey: "fixedPointY") != nil {
            fixedPoint = CGPoint(
                x: defaults.double(forKey: "fixedPointX"),
                y: defaults.double(forKey: "fixedPointY")
            )
        } else {
            fixedPoint = nil
        }

        refreshRunningApplications()
    }

    var validationMessage: String? {
        switch SettingsValidator.validate(intervalText: intervalText, repeatText: repeatText) {
        case .success:
            if targetMode == .fixedPoint, fixedPoint == nil {
                return "Hãy chọn một điểm click cố định."
            }

            if let error = ApplicationLockValidator.validate(
                isEnabled: applicationLockEnabled,
                selectedBundleIdentifier: selectedApplicationIdentifier,
                isApplicationRunning: selectedRunningApplication != nil
            ) {
                return error.errorDescription
            }
            return nil
        case let .failure(error):
            return error.errorDescription
        }
    }

    var fixedPointDescription: String {
        guard let fixedPoint else { return "Chưa chọn điểm" }
        return "X: \(Int(fixedPoint.x.rounded()))  Y: \(Int(fixedPoint.y.rounded()))"
    }

    var selectedApplicationIsRunning: Bool {
        selectedRunningApplication != nil
    }

    func refreshRunningApplications() {
        runningApplications = RunningApplicationOption.current()
    }

    /// Dựng Kịch bản một bước tương đương với biểu mẫu hiện tại (UI-6).
    func makeScenario() -> Scenario? {
        guard case let .success(settings) = SettingsValidator.validate(
            intervalText: intervalText,
            repeatText: repeatText
        ) else { return nil }

        let target: StepTarget
        switch targetMode {
        case .cursor:
            target = .cursor
        case .fixedPoint:
            guard let fixedPoint else { return nil }
            target = .screenPoint(x: fixedPoint.x, y: fixedPoint.y)
        }

        var lockedApplication: LockedApplication?
        if applicationLockEnabled, !selectedApplicationIdentifier.isEmpty {
            lockedApplication = LockedApplication(
                bundleIdentifier: selectedApplicationIdentifier,
                name: selectedApplicationName
            )
        }

        return Scenario(
            name: "Chế độ đơn giản",
            steps: [
                Step(
                    action: .click(button: .left, count: 1, holdMilliseconds: 0),
                    target: target,
                    repeatCount: settings.repeatCount,
                    delayMillisecondsAfter: settings.intervalMilliseconds
                )
            ],
            runCount: .times(1),
            lockedApplication: lockedApplication
        )
    }

    @discardableResult
    func start() -> Bool {
        guard let scenario = makeScenario() else {
            message = validationMessage
            return false
        }
        message = nil
        return runner.start(scenario)
    }

    func chooseFixedPoint(returningTo returnWindow: NSWindow?) {
        guard !runner.isRunning else { return }

        message = "Click vào vị trí muốn lưu; nhấn Esc để hủy."
        let selector = ClickPointSelector()
        pointSelector = selector

        selector.start { [weak self] point in
            guard let self else { return }
            self.pointSelector = nil
            NSApp.activate(ignoringOtherApps: true)
            returnWindow?.makeKeyAndOrderFront(nil)

            guard let point else {
                self.message = "Đã hủy chọn điểm."
                return
            }

            self.fixedPoint = point
            self.targetMode = .fixedPoint
            self.defaults.set(Double(point.x), forKey: "fixedPointX")
            self.defaults.set(Double(point.y), forKey: "fixedPointY")
            self.message = "Đã lưu điểm click: \(self.fixedPointDescription)"
        }
    }

    func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    private func saveValidSettings() {
        guard case let .success(settings) = SettingsValidator.validate(
            intervalText: intervalText,
            repeatText: repeatText
        ) else { return }

        defaults.set(settings.intervalMilliseconds, forKey: "intervalMilliseconds")
        defaults.set(settings.repeatCount, forKey: "repeatCount")
    }

    private var selectedRunningApplication: NSRunningApplication? {
        guard !selectedApplicationIdentifier.isEmpty else { return nil }
        return NSWorkspace.shared.runningApplications.first {
            $0.bundleIdentifier == selectedApplicationIdentifier && !$0.isTerminated
        }
    }

    private func saveSelectedApplication() {
        defaults.set(selectedApplicationIdentifier, forKey: "selectedApplicationIdentifier")
        if let selectedOption = runningApplications.first(where: {
            $0.bundleIdentifier == selectedApplicationIdentifier
        }) {
            selectedApplicationName = selectedOption.name
            defaults.set(selectedOption.name, forKey: "selectedApplicationName")
        }
    }
}
