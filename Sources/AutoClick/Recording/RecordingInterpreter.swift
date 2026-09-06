import CoreGraphics
import Foundation

enum RecordingLimits {
    /// Giữ lâu hơn mức này thì là giữ nhấn, ngắn hơn là click thường (RC-5, RC-6).
    static let longPressThresholdMilliseconds = 400
    /// Xê dịch trong ngưỡng này vẫn coi như đứng yên — tay người không bao giờ thật sự bất động.
    static let movementTolerancePoints = 3.0
    /// Hai click cách nhau xa hơn mức này thì không gộp thành double click (RC-7).
    static let doubleClickTolerancePoints = 5.0
    /// Hai sự kiện cuộn cách nhau dưới mức này thuộc cùng một tràng (RC-9).
    static let scrollCoalesceGapMilliseconds = 150
}

/// Một sự kiện chuột thô lấy từ `CGEventTap`.
struct RecordedEvent: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case mouseDown(MouseButton)
        case mouseUp(MouseButton)
        case mouseDragged(MouseButton)
        case scroll(deltaX: Int, deltaY: Int)
    }

    var kind: Kind
    var location: CGPoint
    var timestamp: TimeInterval
    var processIdentifier: pid_t?
    var windowFrame: CGRect?
}

/// Một Bước đã suy luận xong nhưng còn ở toạ độ tuyệt đối.
///
/// Việc nâng lên **Vị trí** tương đối **Cửa sổ neo** (RC-13) diễn ra sau, ở `ScenarioRecorder`,
/// vì nó cần biết toàn bộ phiên ghi nằm trong một hay nhiều ứng dụng.
struct RecordedStep: Equatable, Sendable {
    var action: StepAction
    var location: CGPoint
    var endLocation: CGPoint?
    var delayMillisecondsAfter: Int
    var processIdentifier: pid_t?
    var windowFrame: CGRect?
}

/// Biến chuỗi sự kiện thô thành các **Hành động** cấp cao (RC-5…RC-11).
///
/// Hàm thuần tuý: không đụng tới `CGEventTap`, không đụng tới đồng hồ hệ thống. Toàn bộ quy tắc
/// nhận dạng double click / giữ nhấn / kéo thả nằm ở đây và kiểm chứng được bằng dữ liệu dựng sẵn.
enum RecordingInterpreter {
    static func steps(
        from events: [RecordedEvent],
        doubleClickInterval: TimeInterval = 0.5
    ) -> [RecordedStep] {
        let merged = merge(gestures(from: events), doubleClickInterval: doubleClickInterval)
        return withDelays(merged)
    }

    // MARK: - Gom sự kiện thành cử chỉ

    private struct Gesture {
        var action: StepAction
        var location: CGPoint
        var endLocation: CGPoint?
        var startTime: TimeInterval
        var endTime: TimeInterval
        var processIdentifier: pid_t?
        var windowFrame: CGRect?
        /// Chỉ có ở cử chỉ click ngắn; dùng để gộp thành double click.
        var clickButton: MouseButton?
    }

    private static func gestures(from events: [RecordedEvent]) -> [Gesture] {
        var result: [Gesture] = []
        var index = 0

        while index < events.count {
            switch events[index].kind {
            case let .mouseDown(button):
                guard let upIndex = indexOfMouseUp(for: button, in: events, after: index) else {
                    // Nhấn xuống mà không có nhả — phiên ghi kết thúc giữa chừng. Bỏ qua.
                    index += 1
                    continue
                }
                result.append(pressGesture(events, downIndex: index, upIndex: upIndex, button: button))
                index = upIndex + 1

            case .scroll:
                let (gesture, nextIndex) = scrollGesture(events, from: index)
                result.append(gesture)
                index = nextIndex

            case .mouseUp, .mouseDragged:
                // Nhả hoặc kéo mồ côi: bắt đầu ghi giữa lúc người dùng đang giữ chuột.
                index += 1
            }
        }

        return result
    }

    private static func indexOfMouseUp(
        for button: MouseButton,
        in events: [RecordedEvent],
        after downIndex: Int
    ) -> Int? {
        events[(downIndex + 1)...].firstIndex { $0.kind == .mouseUp(button) }
    }

    private static func pressGesture(
        _ events: [RecordedEvent],
        downIndex: Int,
        upIndex: Int,
        button: MouseButton
    ) -> Gesture {
        let down = events[downIndex]
        let up = events[upIndex]
        let holdMilliseconds = milliseconds(from: down.timestamp, to: up.timestamp)
        let travelled = distance(down.location, up.location) > RecordingLimits.movementTolerancePoints

        if travelled {
            // RC-8: chỉ giữ điểm đầu và điểm cuối; đường đi được dựng lại khi chạy (EX-20).
            return Gesture(
                action: .drag(
                    button: button,
                    destination: .screenPoint(x: up.location.x, y: up.location.y)
                ),
                location: down.location,
                endLocation: up.location,
                startTime: down.timestamp,
                endTime: up.timestamp,
                processIdentifier: down.processIdentifier,
                windowFrame: down.windowFrame
            )
        }

        let isLongPress = holdMilliseconds > RecordingLimits.longPressThresholdMilliseconds
        return Gesture(
            action: .click(
                button: button,
                count: 1,
                holdMilliseconds: isLongPress ? holdMilliseconds : 0
            ),
            location: down.location,
            endLocation: nil,
            startTime: down.timestamp,
            endTime: up.timestamp,
            processIdentifier: down.processIdentifier,
            windowFrame: down.windowFrame,
            clickButton: isLongPress ? nil : button
        )
    }

    /// RC-9: một lần cuộn trackpad phát khoảng 100 sự kiện. Không gộp thì bản ghi thành 100 Bước.
    private static func scrollGesture(
        _ events: [RecordedEvent],
        from startIndex: Int
    ) -> (Gesture, Int) {
        var totalX = 0
        var totalY = 0
        var index = startIndex
        var lastTimestamp = events[startIndex].timestamp

        while index < events.count,
              case let .scroll(deltaX, deltaY) = events[index].kind,
              milliseconds(from: lastTimestamp, to: events[index].timestamp)
                <= RecordingLimits.scrollCoalesceGapMilliseconds {
            totalX += deltaX
            totalY += deltaY
            lastTimestamp = events[index].timestamp
            index += 1
        }

        let first = events[startIndex]
        return (
            Gesture(
                action: .scroll(deltaX: totalX, deltaY: totalY),
                location: first.location,
                endLocation: nil,
                startTime: first.timestamp,
                endTime: lastTimestamp,
                processIdentifier: first.processIdentifier,
                windowFrame: first.windowFrame
            ),
            index
        )
    }

    // MARK: - Gộp double click

    private static func merge(
        _ gestures: [Gesture],
        doubleClickInterval: TimeInterval
    ) -> [Gesture] {
        var result: [Gesture] = []

        for gesture in gestures {
            guard let button = gesture.clickButton,
                  var previous = result.last,
                  previous.clickButton == button,
                  case let .click(_, count, _) = previous.action,
                  gesture.startTime - previous.endTime < doubleClickInterval,
                  distance(previous.location, gesture.location)
                    <= RecordingLimits.doubleClickTolerancePoints else {
                result.append(gesture)
                continue
            }

            previous.action = .click(button: button, count: count + 1, holdMilliseconds: 0)
            previous.endTime = gesture.endTime
            result[result.count - 1] = previous
        }

        return result
    }

    // MARK: - Thời gian

    /// RC-10: khoảng chờ là khoảng cách thật giữa hai cử chỉ, không cắt trần, không làm tròn
    /// (ADR-0004). RC-11: Bước cuối cùng có khoảng chờ 0.
    private static func withDelays(_ gestures: [Gesture]) -> [RecordedStep] {
        gestures.enumerated().map { index, gesture in
            let delay = index + 1 < gestures.count
                ? milliseconds(from: gesture.endTime, to: gestures[index + 1].startTime)
                : 0

            return RecordedStep(
                action: gesture.action,
                location: gesture.location,
                endLocation: gesture.endLocation,
                delayMillisecondsAfter: delay.clamped(to: ScenarioLimits.delayMilliseconds),
                processIdentifier: gesture.processIdentifier,
                windowFrame: gesture.windowFrame
            )
        }
    }

    private static func milliseconds(from start: TimeInterval, to end: TimeInterval) -> Int {
        max(0, Int(((end - start) * 1000).rounded()))
    }

    private static func distance(_ lhs: CGPoint, _ rhs: CGPoint) -> Double {
        ((lhs.x - rhs.x) * (lhs.x - rhs.x) + (lhs.y - rhs.y) * (lhs.y - rhs.y)).squareRoot()
    }
}
