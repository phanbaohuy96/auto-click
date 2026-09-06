import CoreGraphics
import Foundation
import Testing
@testable import AutoClick

// MARK: - Neo cửa sổ

/// DM-18: Vị trí tương đối cửa sổ không giải được nếu thiếu Ứng dụng khoá, nên chặn từ lúc kiểm
/// tra chứ không để chạy rồi mới hỏng.
@MainActor
@Test func aWindowRelativeStepWithoutALockedApplicationIsRefused() {
    let recorder = EventRecorder()
    let runner = makeRunner(recorder: recorder)
    let scenario = Scenario(
        name: "Thiếu khoá",
        steps: [Step(action: .move, target: .windowRelative(corner: .topLeft, dx: 10, dy: 10))]
    )

    #expect(runner.validate(scenario) == .missingLockedApplication)
    #expect(!runner.start(scenario))
    #expect(recorder.records.isEmpty)
}

@MainActor
@Test func aWindowRelativeStepResolvesAgainstTheAnchorWindow() async {
    let recorder = EventRecorder()
    let system = FakeSystem()
    system.anchorWindowFrame = CGRect(x: 700, y: 300, width: 800, height: 600)
    let runner = makeRunner(recorder: recorder, system: system)

    let scenario = Scenario(
        name: "Neo",
        steps: [
            Step(
                action: .move,
                target: .windowRelative(corner: .topLeft, dx: 120, dy: 88),
                delayMillisecondsAfter: 0
            )
        ],
        lockedApplication: FakeSystem.lockedApplication
    )

    #expect(runner.start(scenario))
    #expect(await waitUntil { !runner.isRunning })
    #expect(recorder.records.first?.location == CGPoint(x: 820, y: 388))
}

/// EX-7: không lấy được cửa sổ nào thì dừng, và thông báo phải nêu tên ứng dụng.
@MainActor
@Test func aMissingAnchorWindowStopsTheScenarioWithANamedMessage() async {
    let recorder = EventRecorder()
    let system = FakeSystem()
    system.anchorWindowFrame = nil
    let runner = makeRunner(recorder: recorder, system: system)

    let scenario = Scenario(
        name: "Không cửa sổ",
        steps: [Step(action: .move, target: .windowRelative(corner: .topLeft, dx: 1, dy: 1))],
        lockedApplication: FakeSystem.lockedApplication
    )

    #expect(runner.start(scenario))
    #expect(await waitUntil { !runner.isRunning })
    #expect(recorder.records.isEmpty)
    #expect(runner.statusText.contains("App Thử"))
}

// MARK: - Kéo thả

/// EX-20: nhiều ứng dụng bỏ qua thao tác kéo nếu con trỏ nhảy thẳng từ đầu tới cuối.
@MainActor
@Test func draggingPassesThroughIntermediatePoints() async {
    let recorder = EventRecorder()
    let runner = makeRunner(recorder: recorder)
    let scenario = Scenario(
        name: "Kéo",
        steps: [
            Step(
                action: .drag(button: .left, destination: .screenPoint(x: 300, y: 100)),
                target: .screenPoint(x: 100, y: 100),
                delayMillisecondsAfter: 0
            )
        ]
    )

    #expect(runner.start(scenario))
    #expect(await waitUntil { !runner.isRunning })

    #expect(recorder.types.first == .leftMouseDown)
    #expect(recorder.types.last == .leftMouseUp)
    #expect(
        recorder.types.filter { $0 == .leftMouseDragged }.count
            == ScenarioLimits.dragIntermediateSteps
    )
    #expect(recorder.records.first?.location == CGPoint(x: 100, y: 100))
    #expect(recorder.records.last?.location == CGPoint(x: 300, y: 100))
    // Các điểm trung gian phải tiến dần chứ không nhảy cóc.
    let xs = recorder.records.map(\.location.x)
    #expect(zip(xs, xs.dropFirst()).allSatisfy { $0 <= $1 })
}

/// SF-1 áp cho cả kéo thả: dừng giữa lúc đang kéo vẫn phải nhả nút.
@MainActor
@Test func stoppingMidDragStillReleasesTheMouseButton() async {
    let recorder = EventRecorder()
    let runner = makeRunner(recorder: recorder)
    let scenario = Scenario(
        name: "Kéo dài",
        steps: [
            Step(
                action: .drag(button: .left, destination: .screenPoint(x: 2000, y: 100)),
                target: .screenPoint(x: 100, y: 100),
                delayMillisecondsAfter: 0
            )
        ]
    )

    #expect(runner.start(scenario))
    #expect(await waitUntil { recorder.types.contains(.leftMouseDragged) })
    #expect(!recorder.types.contains(.leftMouseUp))

    runner.stop()

    #expect(recorder.types.contains(.leftMouseUp))
}

// MARK: - Bàn phím

/// SF-4: sự kiện bàn phím không mang toạ độ nên `EX-10` không bảo vệ được nó.
@MainActor
@Test func aKeyboardStepBringsTheLockedApplicationToFrontFirst() async {
    let recorder = EventRecorder()
    let system = FakeSystem()
    system.frontmostProcessIdentifier = 9999  // một ứng dụng khác vừa cướp focus
    let runner = makeRunner(recorder: recorder, system: system)

    let scenario = Scenario(
        name: "Gõ",
        steps: [Step(action: .typeText("hi"), target: .cursor, delayMillisecondsAfter: 0)],
        lockedApplication: FakeSystem.lockedApplication
    )

    #expect(runner.start(scenario))
    #expect(await waitUntil { !runner.isRunning })

    #expect(system.frontmostProcessIdentifier == FakeSystem.applicationProcessIdentifier)
    #expect(recorder.records.count == 4)  // hai ký tự × (down + up)
}

@MainActor
@Test func aKeyboardStepStopsWhenTheApplicationCannotBeBroughtToFront() async {
    let recorder = EventRecorder()
    let system = FakeSystem()
    system.frontmostProcessIdentifier = 9999
    system.activationSucceeds = false
    let runner = makeRunner(recorder: recorder, system: system)

    let scenario = Scenario(
        name: "Gõ hỏng",
        steps: [Step(action: .typeText("hi"), target: .cursor, delayMillisecondsAfter: 0)],
        lockedApplication: FakeSystem.lockedApplication
    )

    #expect(runner.start(scenario))
    #expect(await waitUntil { !runner.isRunning })

    #expect(recorder.records.isEmpty)
    #expect(runner.statusText.contains("App Thử"))
}

/// EX-22: tổ hợp phím gửi mã phím vật lý kèm cờ phím bổ trợ.
@MainActor
@Test func aKeyStrokeSendsItsKeyCodeAndModifierFlags() async {
    let recorder = EventRecorder()
    let runner = makeRunner(recorder: recorder)
    let scenario = Scenario(
        name: "Copy",
        steps: [
            Step(
                action: .pressKey(KeyStroke(key: "c", modifiers: [.command])),
                target: .cursor,
                delayMillisecondsAfter: 0
            )
        ]
    )

    #expect(runner.start(scenario))
    #expect(await waitUntil { !runner.isRunning })

    #expect(recorder.records.count == 2)
    #expect(recorder.records.allSatisfy { $0.keyCode == Int64(KeyCatalog.keyCode(for: "c")!) })
    #expect(recorder.records.allSatisfy { $0.flags.contains(.maskCommand) })
}

@MainActor
@Test func anUnknownKeyNameStopsTheScenario() async {
    let recorder = EventRecorder()
    let runner = makeRunner(recorder: recorder)
    let scenario = Scenario(
        name: "Phím lạ",
        steps: [Step(action: .pressKey(KeyStroke(key: "khongton")), target: .cursor)]
    )

    #expect(runner.start(scenario))
    #expect(await waitUntil { !runner.isRunning })

    #expect(recorder.records.isEmpty)
    #expect(runner.statusText.contains("khongton"))
}

@Test func keyStrokeModifiersAreNormalisedSoEqualStrokesCompareEqual() {
    let a = KeyStroke(key: "c", modifiers: [.command, .shift])
    let b = KeyStroke(key: "c", modifiers: [.shift, .command, .command])

    #expect(a == b)
    #expect(KeyCatalog.describe(a) == "⌘⇧C")
}
