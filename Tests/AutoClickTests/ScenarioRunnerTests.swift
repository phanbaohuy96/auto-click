import CoreGraphics
import Foundation
import Testing
@testable import AutoClick

/// SF-1 / EX-14: đây là hành vi duy nhất trong Auto Click có thể khoá máy người dùng — dừng
/// giữa lúc đang giữ nút mà không nhả thì hệ điều hành tin rằng nút chuột vẫn đang bị giữ.
@MainActor
@Test func stoppingDuringAHoldStillReleasesTheMouseButton() async throws {
    let recorder = EventRecorder()
    let runner = makeRunner(recorder: recorder)
    let scenario = Scenario(
        name: "Giữ lâu",
        steps: [
            Step(
                action: .click(button: .left, count: 1, holdMilliseconds: 30_000),
                target: .screenPoint(x: 100, y: 200),
                delayMillisecondsAfter: 0
            )
        ]
    )

    #expect(runner.start(scenario))
    #expect(await waitUntil { recorder.types.contains(.leftMouseDown) })
    #expect(!recorder.types.contains(.leftMouseUp))

    runner.stop()

    #expect(recorder.types.contains(.leftMouseUp))
    #expect(recorder.records.last?.location == CGPoint(x: 100, y: 200))
    #expect(!runner.isRunning)
}

/// EX-16: thiếu `mouseEventClickState` thì AppKit coi đó là hai click rời, không phải double click.
@MainActor
@Test func doubleClickNumbersItsClickState() async throws {
    let recorder = EventRecorder()
    let runner = makeRunner(recorder: recorder)
    let scenario = Scenario(
        name: "Double",
        steps: [
            Step(
                action: .click(button: .left, count: 2, holdMilliseconds: 0),
                target: .screenPoint(x: 5, y: 6),
                delayMillisecondsAfter: 0
            )
        ]
    )

    #expect(runner.start(scenario))
    #expect(await waitUntil { recorder.records.count >= 4 })

    #expect(recorder.types == [.leftMouseDown, .leftMouseUp, .leftMouseDown, .leftMouseUp])
    #expect(recorder.records.map(\.clickState) == [1, 1, 2, 2])
}

/// EX-4: hai bộ đếm lồng nhau — vòng lặp Kịch bản bọc ngoài vòng lặp Bước.
@MainActor
@Test func stepsRunInOrderInsideEachScenarioIteration() async throws {
    let recorder = EventRecorder()
    let runner = makeRunner(recorder: recorder)
    let scenario = Scenario(
        name: "Lồng nhau",
        steps: [
            Step(action: .move, target: .screenPoint(x: 1, y: 1), delayMillisecondsAfter: 0),
            Step(
                action: .move,
                target: .screenPoint(x: 2, y: 2),
                repeatCount: 2,
                delayMillisecondsAfter: 0
            )
        ],
        runCount: .times(2)
    )

    #expect(runner.start(scenario))
    #expect(await waitUntil { !runner.isRunning })

    #expect(recorder.records.map(\.location.x) == [1, 2, 2, 1, 2, 2])
}

/// DM-19 / EX-6: Vị trí theo con trỏ được giải lại ở từng lần lặp.
@MainActor
@Test func cursorTargetIsResolvedForEveryRepeat() async throws {
    let recorder = EventRecorder()
    let runner = makeRunner(recorder: recorder)
    let scenario = Scenario(
        name: "Con trỏ",
        steps: [
            Step(action: .move, target: .cursor, repeatCount: 3, delayMillisecondsAfter: 0)
        ]
    )

    #expect(runner.start(scenario))
    #expect(await waitUntil { !runner.isRunning })

    #expect(recorder.records.count == 3)
    #expect(recorder.records.allSatisfy { $0.location == CGPoint(x: 7, y: 8) })
}

@MainActor
@Test func anEmptyScenarioIsRefusedBeforeAnyEventIsPosted() {
    let recorder = EventRecorder()
    let runner = makeRunner(recorder: recorder)

    #expect(runner.validate(Scenario(name: "Rỗng")) == .emptyScenario)
    #expect(!runner.start(Scenario(name: "Rỗng")))
    #expect(recorder.records.isEmpty)
    #expect(!runner.isRunning)
}

/// EX-3: huỷ trong lúc đếm ngược thì không phát sự kiện nào.
@MainActor
@Test func stoppingDuringTheCountdownPostsNothing() async throws {
    let recorder = EventRecorder()
    let runner = makeRunner(recorder: recorder, countdownSeconds: 3)
    let scenario = Scenario(
        name: "Đếm ngược",
        steps: [Step(action: .move, target: .cursor, delayMillisecondsAfter: 0)]
    )

    #expect(runner.start(scenario))
    #expect(await waitUntil { runner.countdown != nil })
    runner.stop()
    try await Task.sleep(for: .milliseconds(50))

    #expect(recorder.records.isEmpty)
}

/// SF-9: Kịch bản không giới hạn vẫn phải kiểm tra huỷ ở mỗi Bước, để ⌥⌘S có tác dụng.
@MainActor
@Test func anUnlimitedScenarioStopsWithinOneStep() async throws {
    let recorder = EventRecorder()
    let runner = makeRunner(recorder: recorder)
    let scenario = Scenario(
        name: "Không giới hạn",
        steps: [Step(action: .move, target: .cursor, delayMillisecondsAfter: 0)],
        runCount: .untilStopped
    )

    #expect(runner.start(scenario))
    #expect(await waitUntil { recorder.records.count > 3 })
    #expect(runner.isRunning)

    runner.stop()
    let countAtStop = recorder.records.count
    try await Task.sleep(for: .milliseconds(80))

    #expect(!runner.isRunning)
    #expect(recorder.records.count == countAtStop)
}
