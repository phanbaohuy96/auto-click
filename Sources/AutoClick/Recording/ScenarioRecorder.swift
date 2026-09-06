import AppKit
import CoreGraphics
import Foundation
import os

/// Ghi thao tác chuột thật của người dùng thành một **Kịch bản** (RC-1…RC-17).
///
/// Chỉ quan sát chuột. Ghi bàn phím sẽ đòi quyền Input Monitoring và biến ứng dụng thành
/// keylogger toàn hệ thống — xem [ADR-0003].
@MainActor
final class ScenarioRecorder: ObservableObject {
    @Published private(set) var isRecording = false {
        didSet { onRecordingStateChanged?(isRecording) }
    }
    @Published private(set) var recordedGestureCount = 0
    @Published private(set) var message: String?

    var onRecordingStateChanged: ((Bool) -> Void)?
    /// Gọi khi phiên ghi kết thúc và có ít nhất một Bước (RC-16, RC-17).
    var onFinished: ((RecordingAssembler.Result) -> Void)?

    private static let logger = Logger(subsystem: "com.local.AutoClick", category: "Recorder")

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var events: [RecordedEvent] = []
    private let ownProcessIdentifier = ProcessInfo.processInfo.processIdentifier

    // MARK: - Vòng đời

    @discardableResult
    func start() -> Bool {
        guard !isRecording else { return false }
        guard AXIsProcessTrusted() else {
            message = "Hãy cấp quyền Accessibility rồi thử lại."
            return false
        }

        let mask: CGEventMask = [
            CGEventType.leftMouseDown, .leftMouseUp, .leftMouseDragged,
            .rightMouseDown, .rightMouseUp, .rightMouseDragged,
            .otherMouseDown, .otherMouseUp, .otherMouseDragged,
            .scrollWheel
        ].reduce(into: CGEventMask(0)) { $0 |= 1 << $1.rawValue }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                let recorder = Unmanaged<ScenarioRecorder>.fromOpaque(context).takeUnretainedValue()
                MainActor.assumeIsolated { recorder.handle(type: type, event: event) }
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            message = "Không tạo được bộ lắng nghe sự kiện."
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        // Gắn vào run loop chính để việc hỏi Accessibility ngay trong callback là hợp lệ (RC-18).
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = source
        events.removeAll()
        recordedGestureCount = 0
        message = nil
        isRecording = true
        return true
    }

    func stop() {
        guard isRecording else { return }
        teardown()
        isRecording = false

        let recorded = RecordingInterpreter.steps(
            from: events,
            doubleClickInterval: NSEvent.doubleClickInterval
        )
        events.removeAll()

        guard !recorded.isEmpty else {
            // RC-17: không ghi được Bước nào thì không tạo Kịch bản.
            message = "Không ghi được thao tác nào."
            return
        }

        let result = RecordingAssembler.scenario(
            named: defaultName(for: recorded),
            from: recorded,
            lockedApplication: lockedApplication(for: recorded)
        )
        message = result.warning ?? "Đã ghi \(recorded.count) bước."
        onFinished?(result)
    }

    private func teardown() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    // MARK: - Bắt sự kiện

    private func handle(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            // Hệ thống tắt tap khi callback chạy quá lâu; bật lại thay vì im lặng ngừng ghi.
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            Self.logger.warning("Event tap bị tắt, đã bật lại")
            return
        }

        guard let kind = Self.kind(of: type, event: event) else { return }

        let isGestureStart: Bool
        switch kind {
        case .mouseDown, .scroll: isGestureStart = true
        case .mouseUp, .mouseDragged: isGestureStart = false
        }

        // RC-2: bỏ sự kiện thuộc chính Auto Click ra khỏi bản ghi.
        var processIdentifier: pid_t?
        var windowFrame: CGRect?
        if isGestureStart {
            processIdentifier = NSWorkspace.shared.frontmostApplication?.processIdentifier
            if processIdentifier == ownProcessIdentifier { return }
            if let processIdentifier {
                windowFrame = WindowAnchor.focusedWindowFrame(ofProcess: processIdentifier)
            }
            recordedGestureCount += 1
        }

        events.append(
            RecordedEvent(
                kind: kind,
                location: event.location,
                timestamp: Date().timeIntervalSinceReferenceDate,
                processIdentifier: processIdentifier ?? events.last?.processIdentifier,
                windowFrame: windowFrame ?? events.last?.windowFrame
            )
        )
    }

    private static func kind(of type: CGEventType, event: CGEvent) -> RecordedEvent.Kind? {
        switch type {
        case .leftMouseDown: return .mouseDown(.left)
        case .leftMouseUp: return .mouseUp(.left)
        case .leftMouseDragged: return .mouseDragged(.left)
        case .rightMouseDown: return .mouseDown(.right)
        case .rightMouseUp: return .mouseUp(.right)
        case .rightMouseDragged: return .mouseDragged(.right)
        case .otherMouseDown: return .mouseDown(.center)
        case .otherMouseUp: return .mouseUp(.center)
        case .otherMouseDragged: return .mouseDragged(.center)
        case .scrollWheel:
            return .scroll(
                deltaX: Int(event.getIntegerValueField(.scrollWheelEventDeltaAxis2)),
                deltaY: Int(event.getIntegerValueField(.scrollWheelEventDeltaAxis1))
            )
        default:
            return nil
        }
    }

    // MARK: - Đặt tên và khoá ứng dụng

    private func lockedApplication(for recorded: [RecordedStep]) -> LockedApplication? {
        guard let processIdentifier = RecordingAssembler.singleProcessIdentifier(in: recorded),
              let application = NSRunningApplication(processIdentifier: processIdentifier),
              let bundleIdentifier = application.bundleIdentifier else { return nil }

        return LockedApplication(
            bundleIdentifier: bundleIdentifier,
            name: application.localizedName ?? bundleIdentifier
        )
    }

    /// RC-16: tên mặc định theo ứng dụng và thời điểm ghi.
    private func defaultName(for recorded: [RecordedStep]) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM HH:mm"
        let timestamp = formatter.string(from: Date())

        guard let processIdentifier = RecordingAssembler.singleProcessIdentifier(in: recorded),
              let name = NSRunningApplication(processIdentifier: processIdentifier)?.localizedName
        else {
            return "Bản ghi \(timestamp)"
        }
        return "\(name) \(timestamp)"
    }
}
