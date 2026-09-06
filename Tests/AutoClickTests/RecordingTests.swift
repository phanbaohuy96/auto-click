import CoreGraphics
import Foundation
import Testing
@testable import AutoClick

private func down(_ x: Double, _ y: Double, at time: TimeInterval, button: MouseButton = .left, pid: pid_t? = 1, frame: CGRect? = nil) -> RecordedEvent {
    RecordedEvent(kind: .mouseDown(button), location: CGPoint(x: x, y: y), timestamp: time, processIdentifier: pid, windowFrame: frame)
}

private func up(_ x: Double, _ y: Double, at time: TimeInterval, button: MouseButton = .left, pid: pid_t? = 1, frame: CGRect? = nil) -> RecordedEvent {
    RecordedEvent(kind: .mouseUp(button), location: CGPoint(x: x, y: y), timestamp: time, processIdentifier: pid, windowFrame: frame)
}

private func dragged(_ x: Double, _ y: Double, at time: TimeInterval, pid: pid_t? = 1) -> RecordedEvent {
    RecordedEvent(kind: .mouseDragged(.left), location: CGPoint(x: x, y: y), timestamp: time, processIdentifier: pid, windowFrame: nil)
}

private func scroll(_ dy: Int, at time: TimeInterval, pid: pid_t? = 1) -> RecordedEvent {
    RecordedEvent(kind: .scroll(deltaX: 0, deltaY: dy), location: CGPoint(x: 50, y: 50), timestamp: time, processIdentifier: pid, windowFrame: nil)
}

// MARK: - Suy luận Hành động

/// RC-5: nhấn nhả nhanh tại chỗ là một click thường.
@Test func aQuickPressBecomesAPlainClick() {
    let steps = RecordingInterpreter.steps(from: [down(100, 200, at: 0), up(100, 200, at: 0.08)])

    #expect(steps.count == 1)
    #expect(steps[0].action == .click(button: .left, count: 1, holdMilliseconds: 0))
    #expect(steps[0].location == CGPoint(x: 100, y: 200))
}

/// RC-6: giữ lâu hơn ngưỡng là giữ nhấn, và thời gian giữ thật được ghi lại.
@Test func aSlowPressBecomesALongPressCarryingItsRealDuration() {
    let steps = RecordingInterpreter.steps(from: [down(100, 200, at: 0), up(100, 200, at: 0.7)])

    #expect(steps[0].action == .click(button: .left, count: 1, holdMilliseconds: 700))
}

/// RC-7: hai click sát nhau gộp thành double click chứ không phải hai bước rời.
@Test func twoQuickClicksMergeIntoADoubleClick() {
    let steps = RecordingInterpreter.steps(
        from: [
            down(100, 200, at: 0), up(100, 200, at: 0.08),
            down(101, 201, at: 0.19), up(101, 201, at: 0.26)
        ],
        doubleClickInterval: 0.5
    )

    #expect(steps.count == 1)
    #expect(steps[0].action == .click(button: .left, count: 2, holdMilliseconds: 0))
}

@Test func clicksTooFarApartInTimeStaySeparate() {
    let steps = RecordingInterpreter.steps(
        from: [
            down(100, 200, at: 0), up(100, 200, at: 0.08),
            down(100, 200, at: 2.0), up(100, 200, at: 2.08)
        ],
        doubleClickInterval: 0.5
    )

    #expect(steps.count == 2)
}

@Test func clicksTooFarApartInSpaceStaySeparate() {
    let steps = RecordingInterpreter.steps(
        from: [
            down(100, 200, at: 0), up(100, 200, at: 0.08),
            down(400, 200, at: 0.19), up(400, 200, at: 0.26)
        ],
        doubleClickInterval: 0.5
    )

    #expect(steps.count == 2)
}

/// RC-8: di chuyển quá ngưỡng thì là kéo thả, và chỉ điểm đầu/điểm cuối được giữ.
@Test func movingWhileHeldDownBecomesADrag() {
    let steps = RecordingInterpreter.steps(
        from: [
            down(100, 100, at: 0),
            dragged(150, 100, at: 0.05),
            dragged(250, 100, at: 0.10),
            up(300, 100, at: 0.15)
        ]
    )

    #expect(steps.count == 1)
    #expect(
        steps[0].action == .drag(button: .left, destination: .screenPoint(x: 300, y: 100))
    )
    #expect(steps[0].location == CGPoint(x: 100, y: 100))
}

/// RC-9: một lần cuộn trackpad phát khoảng 100 sự kiện. Không gộp thì bản ghi thành 100 Bước.
@Test func aBurstOfScrollEventsBecomesOneStep() {
    var events: [RecordedEvent] = []
    for index in 0..<100 {
        events.append(scroll(-3, at: Double(index) * 0.01))
    }

    let steps = RecordingInterpreter.steps(from: events)

    #expect(steps.count == 1)
    #expect(steps[0].action == .scroll(deltaX: 0, deltaY: -300))
}

@Test func scrollBurstsSeparatedByAPauseStaySeparate() {
    let steps = RecordingInterpreter.steps(
        from: [scroll(-3, at: 0), scroll(-3, at: 0.01), scroll(-3, at: 5.0)]
    )

    #expect(steps.count == 2)
    #expect(steps[0].action == .scroll(deltaX: 0, deltaY: -6))
    #expect(steps[1].action == .scroll(deltaX: 0, deltaY: -3))
}

// MARK: - Thời gian

/// RC-10 / ADR-0004: khoảng chờ giữ nguyên thời gian thật, kể cả khi rất dài. Cắt trần sẽ đoán
/// sai đúng vào lúc quan trọng — "đợi trang tải" và "đi pha cà phê" trông giống hệt nhau.
@Test func gapsKeepTheirRealDurationEvenWhenLong() {
    let steps = RecordingInterpreter.steps(
        from: [
            down(1, 1, at: 0), up(1, 1, at: 0.05),
            down(2, 2, at: 8.05), up(2, 2, at: 8.10)
        ]
    )

    #expect(steps[0].delayMillisecondsAfter == 8000)
}

/// RC-11: Bước cuối cùng không có khoảng chờ treo lơ lửng.
@Test func theLastStepHasNoTrailingDelay() {
    let steps = RecordingInterpreter.steps(from: [down(1, 1, at: 0), up(1, 1, at: 0.05)])

    #expect(steps[0].delayMillisecondsAfter == 0)
}

@Test func anUnmatchedPressIsDroppedRatherThanGuessed() {
    let steps = RecordingInterpreter.steps(from: [down(1, 1, at: 0)])

    #expect(steps.isEmpty)
}

// MARK: - Dựng Kịch bản

/// RC-13: cả phiên nằm trong một ứng dụng thì tự khoá và nâng lên Vị trí tương đối cửa sổ.
@Test func aSingleApplicationRecordingIsUpgradedToWindowRelativeTargets() {
    let frame = CGRect(x: 700, y: 300, width: 800, height: 600)
    let recorded = RecordingInterpreter.steps(
        from: [down(820, 388, at: 0, pid: 42, frame: frame), up(820, 388, at: 0.05, pid: 42, frame: frame)]
    )

    let result = RecordingAssembler.scenario(
        named: "Chrome",
        from: recorded,
        lockedApplication: LockedApplication(bundleIdentifier: "com.google.Chrome", name: "Chrome")
    )

    #expect(result.scenario.steps[0].target == .windowRelative(corner: .topLeft, dx: 120, dy: 88))
    #expect(result.scenario.lockedApplication?.bundleIdentifier == "com.google.Chrome")
    #expect(result.warning == nil)
}

/// RC-14: trải nhiều ứng dụng thì giữ toạ độ tuyệt đối và nói thẳng ra, thay vì để người dùng
/// phát hiện lúc kịch bản bắn trượt.
@Test func aMultiApplicationRecordingStaysAbsoluteAndWarns() {
    let recorded = RecordingInterpreter.steps(
        from: [
            down(10, 10, at: 0, pid: 1), up(10, 10, at: 0.05, pid: 1),
            down(20, 20, at: 1, pid: 2), up(20, 20, at: 1.05, pid: 2)
        ]
    )

    #expect(RecordingAssembler.singleProcessIdentifier(in: recorded) == nil)

    let result = RecordingAssembler.scenario(named: "Hỗn hợp", from: recorded, lockedApplication: nil)

    #expect(result.scenario.steps.allSatisfy { !$0.target.needsAnchorWindow })
    #expect(result.scenario.lockedApplication == nil)
    #expect(result.warning?.contains("2 ứng dụng") == true)
}

@Test func aDragDestinationIsUpgradedTogetherWithItsStart() {
    let frame = CGRect(x: 0, y: 0, width: 1000, height: 1000)
    let recorded = RecordingInterpreter.steps(
        from: [
            down(100, 100, at: 0, pid: 7, frame: frame),
            dragged(500, 500, at: 0.05, pid: 7),
            up(900, 900, at: 0.1, pid: 7, frame: frame)
        ]
    )

    let result = RecordingAssembler.scenario(
        named: "Kéo",
        from: recorded,
        lockedApplication: LockedApplication(bundleIdentifier: "x", name: "X")
    )

    guard case let .drag(_, destination) = result.scenario.steps[0].action else {
        Issue.record("Bước không phải kéo thả")
        return
    }
    #expect(destination == .windowRelative(corner: .bottomRight, dx: -100, dy: -100))
    #expect(result.scenario.steps[0].target == .windowRelative(corner: .topLeft, dx: 100, dy: 100))
}

/// RC-15: Phiên ghi không bao giờ tự sinh Vị trí theo Ảnh mẫu.
@Test func recordingNeverInventsImageTargets() {
    let recorded = RecordingInterpreter.steps(from: [down(1, 1, at: 0), up(1, 1, at: 0.05)])
    let result = RecordingAssembler.scenario(named: "t", from: recorded, lockedApplication: nil)

    #expect(result.scenario.steps.allSatisfy { $0.target == .screenPoint(x: 1, y: 1) })
}

/// Bước ghi được mà mỗi bước lặp đúng một lần — người dùng tự chỉnh sau.
@Test func recordedStepsRepeatExactlyOnce() {
    let recorded = RecordingInterpreter.steps(
        from: [down(1, 1, at: 0), up(1, 1, at: 0.05), down(2, 2, at: 1), up(2, 2, at: 1.05)]
    )
    let result = RecordingAssembler.scenario(named: "t", from: recorded, lockedApplication: nil)

    #expect(result.scenario.steps.allSatisfy { $0.repeatCount == 1 })
    #expect(result.scenario.runCount == .times(1))
}
