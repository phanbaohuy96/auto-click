import CoreGraphics
import Foundation
@testable import AutoClick

/// Hệ thống giả để test kiểm chứng được `SF-4`, `EX-7`, `EX-10` mà không mở ứng dụng thật.
@MainActor
final class FakeSystem {
    static let applicationBundleIdentifier = "com.test.App"
    static let applicationProcessIdentifier: pid_t = 1234

    var isAccessibilityTrusted = true
    var runningApplications: [String: pid_t] = [
        FakeSystem.applicationBundleIdentifier: FakeSystem.applicationProcessIdentifier
    ]
    var terminatedProcesses: Set<pid_t> = []
    var frontmostProcessIdentifier: pid_t? = FakeSystem.applicationProcessIdentifier
    var anchorWindowFrame: CGRect? = CGRect(x: 100, y: 200, width: 800, height: 600)
    var processIdentifierAtPoint: pid_t? = FakeSystem.applicationProcessIdentifier
    /// `false` mô phỏng trường hợp một dialog modal chặn không cho đưa ứng dụng lên trước.
    var activationSucceeds = true
    private(set) var activations: [pid_t] = []

    var bridge: ScenarioSystemBridge {
        ScenarioSystemBridge(
            isAccessibilityTrusted: { [self] in isAccessibilityTrusted },
            processIdentifier: { [self] in runningApplications[$0] },
            isRunning: { [self] in !terminatedProcesses.contains($0) },
            activate: { [self] processIdentifier in
                activations.append(processIdentifier)
                if activationSucceeds { frontmostProcessIdentifier = processIdentifier }
            },
            frontmostProcessIdentifier: { [self] in frontmostProcessIdentifier },
            anchorWindowFrame: { [self] _ in anchorWindowFrame },
            processIdentifierAtPoint: { [self] _ in processIdentifierAtPoint }
        )
    }

    static var lockedApplication: LockedApplication {
        LockedApplication(bundleIdentifier: applicationBundleIdentifier, name: "App Thử")
    }
}

@MainActor
final class EventRecorder {
    struct Record: Equatable {
        var type: CGEventType
        var clickState: Int64
        var location: CGPoint
        var keyCode: Int64
        var flags: CGEventFlags
    }

    private(set) var records: [Record] = []

    var mouseSink: MouseEventEmitter.EventSink {
        { [self] event in append(event) }
    }

    var keyboardSink: KeyboardEventEmitter.EventSink {
        { [self] event in append(event) }
    }

    private func append(_ event: CGEvent) {
        records.append(
            Record(
                type: event.type,
                clickState: event.getIntegerValueField(.mouseEventClickState),
                location: event.location,
                keyCode: event.getIntegerValueField(.keyboardEventKeycode),
                flags: event.flags
            )
        )
    }

    var types: [CGEventType] { records.map(\.type) }
}

@MainActor
func makeRunner(
    recorder: EventRecorder,
    system: FakeSystem = FakeSystem(),
    cursor: CGPoint = CGPoint(x: 7, y: 8),
    countdownSeconds: Int = 0
) -> ScenarioRunner {
    ScenarioRunner(
        resolver: TargetResolver(currentCursorPoint: { cursor }),
        mouse: MouseEventEmitter(sink: recorder.mouseSink),
        keyboard: KeyboardEventEmitter(sink: recorder.keyboardSink),
        system: system.bridge,
        countdownSeconds: countdownSeconds
    )
}

/// Chờ tới khi `condition` đúng, tối đa `timeout`. Bộ chạy làm việc trên MainActor nên test
/// phải nhường lượt chứ không thể chặn.
@MainActor
func waitUntil(
    timeout: Duration = .seconds(3),
    _ condition: () -> Bool
) async -> Bool {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(5))
    }
    return false
}
