import AppKit
import ApplicationServices
import Foundation

struct RunProgress: Equatable, Sendable {
    /// Vòng lặp Kịch bản hiện tại, đếm từ 1.
    var iteration: Int
    /// `nil` khi Kịch bản chạy không giới hạn (UI-14).
    var totalIterations: Int?
    /// Bước hiện tại, đếm từ 1.
    var stepIndex: Int
    var stepCount: Int
}

enum ScenarioRunError: LocalizedError, Equatable {
    case emptyScenario
    case accessibilityDenied
    case lockedApplicationNotRunning(String)
    case lockedApplicationTerminated
    case pointOutsideLockedApplication

    var errorDescription: String? {
        switch self {
        case .emptyScenario:
            return "Kịch bản chưa có bước nào."
        case .accessibilityDenied:
            return "Hãy cấp quyền Accessibility rồi thử lại."
        case let .lockedApplicationNotRunning(name):
            return "\(name) hiện không chạy."
        case .lockedApplicationTerminated:
            return "Ứng dụng đích đã đóng; Auto Click đã dừng."
        case .pointOutsideLockedApplication:
            return "Điểm thao tác không nằm trong ứng dụng đã khoá; Auto Click đã dừng."
        }
    }
}

/// Bộ chạy Kịch bản duy nhất của ứng dụng.
///
/// Chế độ đơn giản không có bộ chạy riêng: nó dựng một Kịch bản một bước rồi gọi vào đây
/// (ADR-0002, UI-6). Nhờ vậy phần dễ sai nhất — phát sự kiện, kiểm tra Ứng dụng khoá, nhả nút
/// chuột khi dừng — chỉ tồn tại một bản.
@MainActor
final class ScenarioRunner: ObservableObject {
    static let defaultCountdownSeconds = 3

    @Published private(set) var isRunning = false {
        didSet { onRunningStateChanged?(isRunning) }
    }
    @Published private(set) var countdown: Int?
    @Published private(set) var progress: RunProgress?
    @Published private(set) var message: String?
    @Published private(set) var runningScenarioName: String?

    var onRunningStateChanged: ((Bool) -> Void)?

    private var task: Task<Void, Never>?
    private let emitter: MouseEventEmitter
    private let resolver: TargetResolver
    private let isAccessibilityTrusted: @MainActor () -> Bool

    /// Số giây đếm ngược trước khi phát sự kiện đầu tiên (EX-1). Test đặt về 0.
    let countdownSeconds: Int

    init(
        resolver: TargetResolver = .live,
        emitter: MouseEventEmitter = MouseEventEmitter(),
        countdownSeconds: Int = ScenarioRunner.defaultCountdownSeconds,
        isAccessibilityTrusted: @escaping @MainActor () -> Bool
            = ScenarioRunner.requestSystemAccessibilityAccess
    ) {
        self.resolver = resolver
        self.emitter = emitter
        self.countdownSeconds = countdownSeconds
        self.isAccessibilityTrusted = isAccessibilityTrusted
    }

    var statusText: String {
        if let countdown {
            return "Bắt đầu sau \(countdown) giây…"
        }
        if let progress {
            let step = "Bước \(progress.stepIndex)/\(progress.stepCount)"
            if let total = progress.totalIterations {
                return total == 1 ? step : "Vòng \(progress.iteration)/\(total) · \(step)"
            }
            return "Vòng \(progress.iteration) · \(step)"
        }
        return message ?? "Sẵn sàng"
    }

    /// Kiểm tra những gì phải đúng *trước khi* phát sự kiện đầu tiên (EX-2).
    func validate(_ scenario: Scenario) -> ScenarioRunError? {
        guard !scenario.steps.isEmpty else { return .emptyScenario }
        if let locked = scenario.lockedApplication {
            guard runningApplication(for: locked.bundleIdentifier) != nil else {
                return .lockedApplicationNotRunning(locked.name)
            }
        }
        return nil
    }

    @discardableResult
    func start(_ scenario: Scenario) -> Bool {
        guard !isRunning else { return false }

        if let error = validate(scenario) {
            message = error.errorDescription
            return false
        }

        guard isAccessibilityTrusted() else {
            message = ScenarioRunError.accessibilityDenied.errorDescription
            return false
        }

        var lockedProcessIdentifier: pid_t?
        if let locked = scenario.lockedApplication,
           let application = runningApplication(for: locked.bundleIdentifier) {
            application.activate(options: [.activateAllWindows])
            lockedProcessIdentifier = application.processIdentifier
        }

        message = nil
        progress = nil
        runningScenarioName = scenario.name
        isRunning = true

        task = Task { [weak self] in
            await self?.run(scenario, lockedProcessIdentifier: lockedProcessIdentifier)
        }
        return true
    }

    /// Mọi đường dừng đều đi qua đây (EX-13).
    func stop() {
        task?.cancel()
        task = nil
        finish(with: "Đã dừng")
    }

    private func finish(with message: String?) {
        // Chạy vô điều kiện, kể cả khi tác vụ đã bị huỷ (SF-1, SF-2).
        emitter.releaseAllHeld()
        countdown = nil
        progress = nil
        runningScenarioName = nil
        isRunning = false
        if let message { self.message = message }
    }

    private func run(_ scenario: Scenario, lockedProcessIdentifier: pid_t?) async {
        var outcome: String?
        defer {
            task = nil
            finish(with: outcome)
        }

        do {
            for second in stride(from: countdownSeconds, through: 1, by: -1) {
                countdown = second
                try await Task.sleep(for: .seconds(1))
            }
            countdown = nil

            var iteration = 0
            while true {
                if let total = scenario.runCount.totalIterations, iteration >= total { break }
                try Task.checkCancellation()
                iteration += 1

                for (index, step) in scenario.steps.enumerated() {
                    try Task.checkCancellation()
                    progress = RunProgress(
                        iteration: iteration,
                        totalIterations: scenario.runCount.totalIterations,
                        stepIndex: index + 1,
                        stepCount: scenario.steps.count
                    )
                    try await perform(step, lockedProcessIdentifier: lockedProcessIdentifier)
                }
            }

            outcome = completionMessage(for: scenario)
        } catch is CancellationError {
            outcome = "Đã dừng"
        } catch {
            outcome = "Có lỗi: \(error.localizedDescription)"
        }
    }

    private func completionMessage(for scenario: Scenario) -> String {
        switch scenario.runCount {
        case let .times(count) where count == 1:
            return "Hoàn tất \(scenario.steps.count) bước"
        case let .times(count):
            return "Hoàn tất \(count) vòng"
        case .untilStopped:
            return "Đã dừng"
        }
    }

    private func perform(_ step: Step, lockedProcessIdentifier: pid_t?) async throws {
        for _ in 0..<step.repeatCount {
            try Task.checkCancellation()

            if let lockedProcessIdentifier,
               NSRunningApplication(processIdentifier: lockedProcessIdentifier) == nil {
                throw ScenarioRunError.lockedApplicationTerminated
            }

            let point = resolver.resolve(step.target)
            try authorize(point, lockedProcessIdentifier: lockedProcessIdentifier)
            try await apply(step.action, at: point)
            try await sleepBetweenEvents(step.delayMillisecondsAfter)
        }
    }

    private func apply(_ action: StepAction, at point: CGPoint) async throws {
        switch action {
        case .move:
            emitter.move(to: point)

        case let .scroll(deltaX, deltaY):
            emitter.scroll(deltaX: deltaX, deltaY: deltaY, at: point)

        case let .click(button, count, holdMilliseconds):
            for clickState in 1...count {
                emitter.press(button, at: point, clickState: clickState)
                if holdMilliseconds > 0 {
                    try await Task.sleep(for: .milliseconds(holdMilliseconds))
                }
                emitter.release(button, at: point, clickState: clickState)
                if clickState < count {
                    try await Task.sleep(
                        for: .milliseconds(ScenarioLimits.interClickGapMilliseconds)
                    )
                }
            }
        }
    }

    /// Nhường ít nhất `minimumEventGapMilliseconds` kể cả khi Bước không có khoảng chờ (SF-8).
    private func sleepBetweenEvents(_ milliseconds: Int) async throws {
        try await Task.sleep(
            for: .milliseconds(max(milliseconds, ScenarioLimits.minimumEventGapMilliseconds))
        )
    }

    private func authorize(_ point: CGPoint, lockedProcessIdentifier: pid_t?) throws {
        let route = ClickRoutingPolicy.route(
            targetProcessIdentifier: lockedProcessIdentifier,
            processIdentifierAtPoint: lockedProcessIdentifier == nil
                ? nil
                : processIdentifierAtPoint(point)
        )
        guard route != nil else { throw ScenarioRunError.pointOutsideLockedApplication }
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

    private func runningApplication(for bundleIdentifier: String) -> NSRunningApplication? {
        guard !bundleIdentifier.isEmpty else { return nil }
        return NSWorkspace.shared.runningApplications.first {
            $0.bundleIdentifier == bundleIdentifier && !$0.isTerminated
        }
    }

    static func requestSystemAccessibilityAccess() -> Bool {
        if AXIsProcessTrusted() { return true }

        // The SDK exposes kAXTrustedCheckOptionPrompt as mutable global state, which Swift 6
        // rejects under strict concurrency checking. This is its documented CFString value.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
