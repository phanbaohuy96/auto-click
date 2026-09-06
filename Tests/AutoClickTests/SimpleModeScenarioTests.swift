import Foundation
import Testing
@testable import AutoClick

@MainActor
private func makeClicker(
    interval: Int = 250,
    repeatCount: Int = 12
) -> AutoClicker {
    let defaults = UserDefaults(suiteName: "AutoClickSimple-\(UUID().uuidString)")!
    defaults.set(interval, forKey: "intervalMilliseconds")
    defaults.set(repeatCount, forKey: "repeatCount")
    return AutoClicker(
        runner: makeRunner(recorder: EventRecorder()),
        defaults: defaults
    )
}

/// UI-6: Chế độ đơn giản không phải bộ chạy thứ hai — nó dựng một Kịch bản một bước.
@MainActor
@Test func simpleModeBuildsASingleStepScenario() throws {
    let clicker = makeClicker(interval: 250, repeatCount: 12)
    clicker.targetMode = .cursor

    let scenario = try #require(clicker.makeScenario())

    #expect(scenario.steps.count == 1)
    #expect(scenario.runCount == .times(1))
    #expect(scenario.steps[0].action == .click(button: .left, count: 1, holdMilliseconds: 0))
    #expect(scenario.steps[0].target == .cursor)
    // Số lần lặp nằm ở Bước, không ở Kịch bản: đó là điều làm "click 200 lần rồi lưu" diễn đạt được.
    #expect(scenario.steps[0].repeatCount == 12)
    #expect(scenario.steps[0].delayMillisecondsAfter == 250)
}

@MainActor
@Test func simpleModeRefusesFixedPointModeWithNoPoint() {
    let clicker = makeClicker()
    clicker.targetMode = .fixedPoint

    #expect(clicker.makeScenario() == nil)
    #expect(clicker.validationMessage == "Hãy chọn một điểm click cố định.")
}

@MainActor
@Test func simpleModeCarriesTheLockedApplicationIntoTheScenario() throws {
    let clicker = makeClicker()
    clicker.targetMode = .cursor
    clicker.applicationLockEnabled = true
    clicker.selectedApplicationIdentifier = "com.google.Chrome"

    let scenario = try #require(clicker.makeScenario())

    #expect(scenario.lockedApplication?.bundleIdentifier == "com.google.Chrome")
}

@MainActor
@Test func simpleModeDropsTheLockWhenItIsTurnedOff() throws {
    let clicker = makeClicker()
    clicker.targetMode = .cursor
    clicker.selectedApplicationIdentifier = "com.google.Chrome"
    clicker.applicationLockEnabled = false

    #expect(try #require(clicker.makeScenario()).lockedApplication == nil)
}
