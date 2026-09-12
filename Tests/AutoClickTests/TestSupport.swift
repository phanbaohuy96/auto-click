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
    /// Cửa sổ của từng tiến trình, theo tiêu đề. Dựng cảnh "hai tiến trình cùng bundle id".
    var windowTitles: [pid_t: [String]] = [:]
    /// Khung riêng của một cửa sổ có tiêu đề cụ thể, khi test cần phân biệt hai cửa sổ.
    var frameForWindowTitle: [String: CGRect] = [:]
    /// Tiến trình nào đã bị hỏi tới, và với tiêu đề nào.
    private(set) var anchorLookups: [(processIdentifier: pid_t, title: String?)] = []
    /// `false` mô phỏng trường hợp một dialog modal chặn không cho đưa ứng dụng lên trước.
    var activationSucceeds = true
    private(set) var activations: [pid_t] = []

    var bridge: ScenarioSystemBridge {
        ScenarioSystemBridge(
            isAccessibilityTrusted: { [self] in isAccessibilityTrusted },
            processIdentifier: { [self] bundleIdentifier, preferredWindowTitle in
                let candidates = runningApplications
                    .filter { $0.key == bundleIdentifier }
                    .map(\.value)
                    .sorted()
                if let title = preferredWindowTitle, !title.isEmpty,
                   let owner = candidates.first(where: {
                       windowTitles[$0]?.contains(title) ?? false
                   }) {
                    return owner
                }
                return candidates.first
            },
            isRunning: { [self] in !terminatedProcesses.contains($0) },
            activate: { [self] processIdentifier in
                activations.append(processIdentifier)
                if activationSucceeds { frontmostProcessIdentifier = processIdentifier }
            },
            frontmostProcessIdentifier: { [self] in frontmostProcessIdentifier },
            anchorWindowFrame: { [self] processIdentifier, preferredWindowTitle in
                anchorLookups.append((processIdentifier, preferredWindowTitle))
                if let title = preferredWindowTitle, let frame = frameForWindowTitle[title] {
                    return frame
                }
                return anchorWindowFrame
            },
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
        /// Chuỗi Unicode gắn trên sự kiện bàn phím — thứ `EX-24` cắt thành khối.
        var unicodeString: String = ""
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
                flags: event.flags,
                unicodeString: EventRecorder.unicodeString(of: event)
            )
        )
    }

    var types: [CGEventType] { records.map(\.type) }

    /// Chuỗi mà một Bước `gõChuỗi` thực sự gửi đi, ghép lại từ mọi khối.
    var typedText: String {
        records.filter { $0.type == .keyDown }.map(\.unicodeString).joined()
    }

    private static func unicodeString(of event: CGEvent) -> String {
        var length = 0
        var buffer = [UniChar](repeating: 0, count: 256)
        event.keyboardGetUnicodeString(
            maxStringLength: buffer.count,
            actualStringLength: &length,
            unicodeString: &buffer
        )
        guard length > 0 else { return "" }
        return String(utf16CodeUnits: buffer, count: length)
    }
}

/// Bộ nhận dạng giả: kiểm chứng ngữ nghĩa thử lại của `EX-8`/`EX-9` mà không chụp màn hình thật.
@MainActor
final class FakeRecognizer: TargetRecognizing {
    /// Lần thử thứ mấy thì "thấy" mục tiêu; `nil` là không bao giờ thấy.
    var foundOnAttempt: Int? = 1
    var point = CGPoint(x: 500, y: 400)
    var error: Error?

    private(set) var attempts = 0
    private(set) var regions: [CGRect?] = []
    private(set) var preparedDirectories: [URL?] = []

    func prepare(templatesDirectory: URL?) {
        preparedDirectories.append(templatesDirectory)
    }

    func locate(_ target: StepTarget, within region: CGRect?) async throws -> CGPoint? {
        attempts += 1
        regions.append(region)
        if let error { throw error }
        guard let foundOnAttempt, attempts >= foundOnAttempt else { return nil }
        return point
    }
}

@MainActor
func makeRunner(
    recorder: EventRecorder,
    system: FakeSystem = FakeSystem(),
    recognizer: TargetRecognizing = FakeRecognizer(),
    cursor: CGPoint = CGPoint(x: 7, y: 8),
    countdownSeconds: Int = 0
) -> ScenarioRunner {
    ScenarioRunner(
        resolver: TargetResolver(currentCursorPoint: { cursor }),
        mouse: MouseEventEmitter(sink: recorder.mouseSink),
        keyboard: KeyboardEventEmitter(sink: recorder.keyboardSink),
        system: system.bridge,
        recognizer: recognizer,
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

/// Môi trường ghi giả: cho phép bơm `CGEvent` dựng sẵn vào `ScenarioRecorder` mà không cần
/// `CGEventTap` thật, tức không cần quyền Accessibility lẫn thao tác tay.
@MainActor
final class FakeRecordingEnvironment {
    static let ownProcessIdentifier: pid_t = 99
    static let otherProcessIdentifier: pid_t = 42

    var frontmostProcessIdentifier: pid_t? = FakeRecordingEnvironment.otherProcessIdentifier
    var anchorWindowFrame: CGRect? = CGRect(x: 100, y: 100, width: 400, height: 300)
    /// Tiêu đề cửa sổ neo mà bộ ghi sẽ đọc được.
    var anchorWindowTitle: String? = "Cửa sổ Thử"
    var applications: [pid_t: LockedApplication] = [
        FakeRecordingEnvironment.otherProcessIdentifier:
            LockedApplication(bundleIdentifier: "com.test.Ghi", name: "App Ghi")
    ]
    var doubleClickInterval: TimeInterval = 0.5
    /// Các cửa sổ của chính Auto Click, theo toạ độ màn hình gốc trên-trái như `CGEvent.location`.
    var ownWindowRects: [CGRect] = []
    /// Tiến trình sở hữu cửa sổ dưới con trỏ; mặc định là ứng dụng đang được ghi.
    var processIdentifierAtPoint: pid_t? = FakeRecordingEnvironment.otherProcessIdentifier
    /// Đồng hồ do test lái: mỗi sự kiện tự chọn thời điểm của mình.
    var now: TimeInterval = 1_000

    var environment: RecordingEnvironment {
        RecordingEnvironment(
            ownProcessIdentifier: { FakeRecordingEnvironment.ownProcessIdentifier },
            frontmostProcessIdentifier: { [self] in frontmostProcessIdentifier },
            pointIsInOwnWindow: { [self] (point: CGPoint) in
                ownWindowRects.contains { $0.contains(point) }
            },
            processIdentifierAtPoint: { [self] _ in processIdentifierAtPoint },
            anchorWindowFrame: { [self] _ in anchorWindowFrame },
            anchorWindowTitle: { [self] _ in anchorWindowTitle },
            application: { [self] in applications[$0] },
            doubleClickInterval: { [self] in doubleClickInterval },
            now: { [self] in now }
        )
    }
}

/// Dựng `CGEvent` thật (tạo sự kiện không cần quyền, chỉ phát mới cần) để test đi qua đúng
/// đường giải mã mà `ScenarioRecorder` dùng với sự kiện từ tap.
enum TestEvent {
    static func mouse(_ type: CGEventType, at point: CGPoint, button: CGMouseButton = .left) -> CGEvent {
        CGEvent(
            mouseEventSource: nil,
            mouseType: type,
            mouseCursorPosition: point,
            mouseButton: button
        )!
    }

    /// `kCGScrollWheelEventDeltaAxis1` là trục dọc, `Axis2` là trục ngang — theo `CGEventTypes.h`.
    static func scroll(deltaX: Int, deltaY: Int, at point: CGPoint) -> CGEvent {
        let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .line,
            wheelCount: 2,
            wheel1: Int32(deltaY),
            wheel2: Int32(deltaX),
            wheel3: 0
        )!
        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: Int64(deltaY))
        event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: Int64(deltaX))
        event.location = point
        return event
    }
}
