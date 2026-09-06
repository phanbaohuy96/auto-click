import CoreGraphics
import Foundation

/// Dựng **Kịch bản** từ các Bước đã suy luận (RC-13, RC-14).
///
/// Hàm thuần tuý, tách khỏi việc bắt sự kiện: đây là chỗ quyết định bản ghi có dùng được ngay
/// hay bắt người dùng sửa tay từng bước, nên nó phải kiểm chứng được.
enum RecordingAssembler {
    struct Result: Equatable {
        var scenario: Scenario
        /// Cảnh báo hiện lên sau khi ghi xong; `nil` nghĩa là bản ghi dùng được ngay.
        var warning: String?
    }

    /// Tiến trình duy nhất mà cả phiên ghi chạm tới, hoặc `nil` nếu trải trên nhiều ứng dụng.
    ///
    /// Một Bước không xác định được tiến trình cũng làm cả phiên mất tư cách: nâng lên tương đối
    /// cửa sổ dựa trên phỏng đoán còn tệ hơn là giữ nguyên toạ độ tuyệt đối và nói rõ ra.
    static func singleProcessIdentifier(in steps: [RecordedStep]) -> pid_t? {
        guard !steps.isEmpty, steps.allSatisfy({ $0.processIdentifier != nil }) else { return nil }
        let identifiers = Set(steps.compactMap(\.processIdentifier))
        return identifiers.count == 1 ? identifiers.first : nil
    }

    static func scenario(
        named name: String,
        from recorded: [RecordedStep],
        lockedApplication: LockedApplication?,
        scenarioIdentifier: UUID = UUID()
    ) -> Result {
        var anchoredCount = 0
        let steps = recorded.map { step -> Step in
            let target = convert(step.location, frame: step.windowFrame, isLocked: lockedApplication != nil)
            if target.needsAnchorWindow { anchoredCount += 1 }

            var action = step.action
            if case let .drag(button, _) = step.action, let endLocation = step.endLocation {
                action = .drag(
                    button: button,
                    destination: convert(
                        endLocation,
                        frame: step.windowFrame,
                        isLocked: lockedApplication != nil
                    )
                )
            }

            return Step(
                action: action,
                target: target,
                repeatCount: 1,
                delayMillisecondsAfter: step.delayMillisecondsAfter
            )
        }

        let scenario = Scenario(
            id: scenarioIdentifier,
            name: name,
            steps: steps,
            runCount: .times(1),
            lockedApplication: lockedApplication
        )

        return Result(scenario: scenario, warning: warning(for: recorded, anchoredCount: anchoredCount))
    }

    private static func convert(
        _ point: CGPoint,
        frame: CGRect?,
        isLocked: Bool
    ) -> StepTarget {
        // RC-13: chỉ nâng lên tương đối khi vừa có Ứng dụng khoá vừa lấy được cửa sổ lúc ghi.
        guard isLocked, let frame, frame.width > 0, frame.height > 0 else {
            return .screenPoint(x: point.x, y: point.y)
        }
        let offset = WindowAnchor.offset(for: point, in: frame)
        return .windowRelative(corner: offset.corner, dx: offset.dx, dy: offset.dy)
    }

    private static func warning(for recorded: [RecordedStep], anchoredCount: Int) -> String? {
        guard !recorded.isEmpty else { return nil }

        let identifiers = Set(recorded.compactMap(\.processIdentifier))
        if identifiers.count > 1 {
            // RC-14: nói thẳng ra thay vì để người dùng phát hiện lúc kịch bản bắn trượt.
            return "Bản ghi trải trên \(identifiers.count) ứng dụng nên dùng toạ độ tuyệt đối; "
                + "các bước sẽ trượt nếu cửa sổ dịch chuyển."
        }
        if anchoredCount < recorded.count {
            return "\(recorded.count - anchoredCount)/\(recorded.count) bước dùng toạ độ tuyệt đối "
                + "vì không lấy được cửa sổ lúc ghi; các bước đó sẽ trượt nếu cửa sổ dịch chuyển."
        }
        return nil
    }
}
