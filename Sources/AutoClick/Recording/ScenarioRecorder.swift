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

    private let environment: RecordingEnvironment
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var events: [RecordedEvent] = []
    /// Đang bỏ qua cú thao tác hiện tại vì nó bấm vào chính Auto Click (`RC-2`).
    private var ignoringGesture = false

    init(environment: RecordingEnvironment = .live) {
        self.environment = environment
    }

    // MARK: - Vòng đời

    @discardableResult
    func start() -> Bool {
        guard !isRecording else { return false }
        guard AXIsProcessTrusted() else {
            message = "Hãy cấp quyền Accessibility cho Auto Click rồi thử lại. Nếu Auto Click đã có trong danh sách, hãy tắt rồi bật lại — bản cập nhật làm quyền cũ hết hiệu lực."
            return false
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: Self.eventMask,
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
        finishSession()
    }

    /// Tách khỏi `stop()` để test chạy được cả đường ghi mà không cần `CGEventTap` thật.
    func finishSession() {
        let recorded = RecordingInterpreter.steps(
            from: events,
            doubleClickInterval: environment.doubleClickInterval()
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

    // MARK: - Những gì được nghe

    /// Loại sự kiện bộ ghi lắng nghe. **Chỉ chuột và cuộn.**
    ///
    /// `SF-6` / [ADR-0003]: thêm `keyDown`, `keyUp` hay `flagsChanged` vào đây là biến Auto Click
    /// thành keylogger toàn hệ thống — nó sẽ thấy mọi phím gõ ở **mọi** ứng dụng, kéo theo quyền
    /// Input Monitoring, và mật khẩu người dùng gõ lúc đang ghi sẽ nằm nguyên văn trong
    /// `scenario.json`. Phát ra phím thì được (chỉ cần Accessibility); **bắt** phím thì không.
    ///
    /// Tách thành hằng số để `theEventMaskContainsNoKeyboardEvent` canh được — trước đây nó nằm
    /// trong thân `startSession`, chỉ `CGEventTap` thật mới chạm tới, tức là không test nào giữ.
    static let recordedEventTypes: [CGEventType] = [
        .leftMouseDown, .leftMouseUp, .leftMouseDragged,
        .rightMouseDown, .rightMouseUp, .rightMouseDragged,
        .otherMouseDown, .otherMouseUp, .otherMouseDragged,
        .scrollWheel
    ]

    static let eventMask: CGEventMask = recordedEventTypes
        .reduce(into: CGEventMask(0)) { $0 |= 1 << $1.rawValue }

    // MARK: - Bắt sự kiện

    func handle(type: CGEventType, event: CGEvent) {
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
            processIdentifier = environment.frontmostProcessIdentifier()
            // Hai phép thử, vì không phép nào đủ một mình: cửa sổ thường thì Auto Click lên trước,
            // còn bảng nổi lúc ghi thì không (`.nonactivatingPanel`) nên phải hỏi theo toạ độ.
            ignoringGesture = processIdentifier == environment.ownProcessIdentifier()
                || environment.pointIsInOwnWindow(event.location)
            if ignoringGesture { return }
            if let processIdentifier {
                windowFrame = environment.anchorWindowFrame(processIdentifier)
            }
            recordedGestureCount += 1
        } else if ignoringGesture {
            // Bỏ nốt phần đuôi của cú thao tác đã bỏ, nếu không bản ghi dính một `mouseUp` mồ côi.
            return
        }

        events.append(
            RecordedEvent(
                kind: kind,
                location: event.location,
                timestamp: environment.now(),
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
        guard let processIdentifier = RecordingAssembler.singleProcessIdentifier(in: recorded)
        else { return nil }
        return environment.application(processIdentifier)
    }

    /// RC-16: tên mặc định theo ứng dụng và thời điểm ghi.
    private func defaultName(for recorded: [RecordedStep]) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM HH:mm"
        let timestamp = formatter.string(from: Date(timeIntervalSinceReferenceDate: environment.now()))

        guard let processIdentifier = RecordingAssembler.singleProcessIdentifier(in: recorded),
              let application = environment.application(processIdentifier)
        else {
            return "Bản ghi \(timestamp)"
        }
        return "\(application.name) \(timestamp)"
    }
}
