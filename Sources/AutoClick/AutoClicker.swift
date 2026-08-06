import AppKit
import ApplicationServices
import Foundation

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
    @Published private(set) var isRunning = false {
        didSet { onRunningStateChanged?(isRunning) }
    }
    @Published private(set) var completedClicks = 0
    @Published private(set) var countdown: Int?
    @Published private(set) var message: String?

    private var clickTask: Task<Void, Never>?
    private var pointSelector: ClickPointSelector?
    private let defaults: UserDefaults
    var onRunningStateChanged: ((Bool) -> Void)?

    init(defaults: UserDefaults = .standard) {
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

    var statusText: String {
        if let countdown {
            return "Bắt đầu sau \(countdown) giây…"
        }
        if isRunning {
            return "Đã click \(completedClicks) lần"
        }
        return message ?? "Sẵn sàng"
    }

    var fixedPointDescription: String {
        guard let fixedPoint else { return "Chưa chọn điểm" }
        return "X: \(Int(fixedPoint.x.rounded()))  Y: \(Int(fixedPoint.y.rounded()))"
    }

    var selectedApplicationIsRunning: Bool {
        selectedRunningApplication != nil
    }

    func refreshRunningApplications() {
        var seenBundleIdentifiers = Set<String>()
        runningApplications = NSWorkspace.shared.runningApplications
            .filter { application in
                application.activationPolicy == .regular
                    && !application.isTerminated
                    && application.processIdentifier != ProcessInfo.processInfo.processIdentifier
                    && application.bundleIdentifier != nil
            }
            .compactMap { application -> RunningApplicationOption? in
                guard let bundleIdentifier = application.bundleIdentifier,
                      seenBundleIdentifiers.insert(bundleIdentifier).inserted else {
                    return nil
                }
                return RunningApplicationOption(
                    bundleIdentifier: bundleIdentifier,
                    name: application.localizedName ?? bundleIdentifier
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    @discardableResult
    func start() -> Bool {
        guard !isRunning else { return false }

        guard case let .success(settings) = SettingsValidator.validate(
            intervalText: intervalText,
            repeatText: repeatText
        ) else {
            message = validationMessage
            return false
        }


        let targetPoint: CGPoint?
        switch targetMode {
        case .cursor:
            targetPoint = nil
        case .fixedPoint:
            guard let fixedPoint else {
                message = "Hãy chọn một điểm click cố định."
                return false
            }
            targetPoint = fixedPoint
        }

        let selectedApplication: NSRunningApplication?
        if applicationLockEnabled {
            guard let runningApplication = selectedRunningApplication else {
                message = ApplicationLockValidator.validate(
                    isEnabled: true,
                    selectedBundleIdentifier: selectedApplicationIdentifier,
                    isApplicationRunning: false
                )?.errorDescription
                refreshRunningApplications()
                return false
            }
            selectedApplication = runningApplication
        } else {
            selectedApplication = nil
        }

        guard requestAccessibilityAccessIfNeeded() else {
            message = "Hãy cấp quyền Accessibility rồi thử lại."
            return false
        }

        selectedApplication?.activate(options: [.activateAllWindows])
        let targetProcessIdentifier = selectedApplication?.processIdentifier

        message = nil
        completedClicks = 0
        isRunning = true

        clickTask = Task { [weak self] in
            await self?.run(
                settings: settings,
                targetPoint: targetPoint,
                targetProcessIdentifier: targetProcessIdentifier
            )
        }
        return true
    }

    func chooseFixedPoint(returningTo returnWindow: NSWindow?) {
        guard !isRunning else { return }

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

    func stop() {
        clickTask?.cancel()
        clickTask = nil
        countdown = nil
        isRunning = false
        message = "Đã dừng"
    }

    func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    private func run(
        settings: AutoClickSettings,
        targetPoint: CGPoint?,
        targetProcessIdentifier: pid_t?
    ) async {
        defer {
            clickTask = nil
            countdown = nil
            isRunning = false
        }

        do {
            for second in stride(from: 3, through: 1, by: -1) {
                countdown = second
                try await Task.sleep(for: .seconds(1))
            }

            countdown = nil
            let positionPolicy = ClickPositionPolicy(
                fixedPoint: targetPoint
            )

            for index in 0..<settings.repeatCount {
                try Task.checkCancellation()
                if let targetProcessIdentifier,
                   NSRunningApplication(processIdentifier: targetProcessIdentifier) == nil {
                    throw AutoClickError.targetApplicationTerminated
                }

                let point = positionPolicy.pointForNextClick(
                    currentCursorPoint: CGEvent(source: nil)?.location ?? .zero
                )
                try postLeftClick(at: point, targetProcessIdentifier: targetProcessIdentifier)
                completedClicks = index + 1

                if index < settings.repeatCount - 1 {
                    try await Task.sleep(for: .milliseconds(settings.intervalMilliseconds))
                }
            }

            message = "Hoàn tất \(settings.repeatCount) lần click"
        } catch is CancellationError {
            message = "Đã dừng"
        } catch {
            message = "Có lỗi: \(error.localizedDescription)"
        }
    }

    private func postLeftClick(at point: CGPoint, targetProcessIdentifier: pid_t?) throws {
        let source = CGEventSource(stateID: .hidSystemState)
        let mouseDown = CGEvent(
            mouseEventSource: source,
            mouseType: .leftMouseDown,
            mouseCursorPosition: point,
            mouseButton: .left
        )
        let mouseUp = CGEvent(
            mouseEventSource: source,
            mouseType: .leftMouseUp,
            mouseCursorPosition: point,
            mouseButton: .left
        )

        let route = ClickRoutingPolicy.route(
            targetProcessIdentifier: targetProcessIdentifier,
            processIdentifierAtPoint: targetProcessIdentifier == nil
                ? nil
                : processIdentifierAtPoint(point)
        )
        switch route {
        case .systemEventTap:
            mouseDown?.post(tap: .cghidEventTap)
            mouseUp?.post(tap: .cghidEventTap)
        case nil:
            throw AutoClickError.pointOutsideTargetApplication
        }
    }

    private func processIdentifierAtPoint(_ point: CGPoint) -> pid_t? {
        let systemWideElement = AXUIElementCreateSystemWide()
        var element: AXUIElement?
        let copyResult = AXUIElementCopyElementAtPosition(
            systemWideElement,
            Float(point.x),
            Float(point.y),
            &element
        )
        guard copyResult == .success, let element else { return nil }

        var processIdentifier: pid_t = 0
        guard AXUIElementGetPid(element, &processIdentifier) == .success else { return nil }
        return processIdentifier
    }

    private func requestAccessibilityAccessIfNeeded() -> Bool {
        if AXIsProcessTrusted() { return true }

        // The SDK exposes kAXTrustedCheckOptionPrompt as mutable global state,
        // which Swift 6 rejects under strict concurrency checking. This is its
        // documented CFString value.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
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

private enum AutoClickError: LocalizedError {
    case targetApplicationTerminated
    case pointOutsideTargetApplication

    var errorDescription: String? {
        switch self {
        case .targetApplicationTerminated:
            return "Ứng dụng đích đã đóng; Auto Click đã dừng."
        case .pointOutsideTargetApplication:
            return "Điểm click không nằm trong ứng dụng đã khóa; Auto Click đã dừng."
        }
    }
}
