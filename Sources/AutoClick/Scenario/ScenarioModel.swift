import CoreGraphics
import Foundation

/// Khoảng hợp lệ của mọi trường số trong một Kịch bản (DM-2, DM-4, DM-6, DM-7).
///
/// Giá trị đọc từ đĩa được kẹp vào các khoảng này thay vì bị từ chối (DM-20).
enum ScenarioLimits {
    static let runCount = 1...1_000_000
    static let stepRepeatCount = 1...1_000_000
    static let delayMilliseconds = 0...3_600_000
    static let clickCount = 1...10
    static let holdMilliseconds = 0...60_000
    static let scrollDelta = -10_000...10_000

    /// Khoảng nhường tối thiểu giữa hai sự kiện liên tiếp (SF-8).
    static let minimumEventGapMilliseconds = 10

    /// Khoảng cách giữa hai cặp nhấn/nhả trong cùng một Hành động click (EX-17).
    static let interClickGapMilliseconds = 30
}

/// Số lần chạy của một Kịch bản (DM-2). Bước luôn dùng số nguyên thuần.
enum RunCount: Equatable, Sendable {
    case times(Int)
    case untilStopped

    var totalIterations: Int? {
        switch self {
        case let .times(count): return count
        case .untilStopped: return nil
        }
    }
}

enum MouseButton: String, CaseIterable, Identifiable, Codable, Sendable {
    case left
    case right
    case center

    var id: String { rawValue }
}

/// Thứ một Bước làm, tách rời khỏi việc làm ở đâu (ADR-0002).
enum StepAction: Equatable, Sendable {
    case click(button: MouseButton, count: Int, holdMilliseconds: Int)
    case scroll(deltaX: Int, deltaY: Int)
    case move
}

/// Nơi một Hành động diễn ra, chỉ giải ra toạ độ lúc chạy (DM-11, DM-12).
enum StepTarget: Equatable, Sendable {
    case cursor
    case screenPoint(x: Double, y: Double)
}

struct Step: Identifiable, Equatable, Sendable {
    var id: UUID
    var action: StepAction
    var target: StepTarget
    var repeatCount: Int
    var delayMillisecondsAfter: Int

    init(
        id: UUID = UUID(),
        action: StepAction,
        target: StepTarget,
        repeatCount: Int = 1,
        delayMillisecondsAfter: Int = 100
    ) {
        self.id = id
        self.action = action
        self.target = target
        self.repeatCount = repeatCount.clamped(to: ScenarioLimits.stepRepeatCount)
        self.delayMillisecondsAfter = delayMillisecondsAfter
            .clamped(to: ScenarioLimits.delayMilliseconds)
    }
}

struct LockedApplication: Equatable, Codable, Sendable {
    var bundleIdentifier: String
    var name: String
}

struct Scenario: Identifiable, Equatable, Sendable {
    var id: UUID
    var name: String
    var steps: [Step]
    var runCount: RunCount
    var lockedApplication: LockedApplication?

    init(
        id: UUID = UUID(),
        name: String,
        steps: [Step] = [],
        runCount: RunCount = .times(1),
        lockedApplication: LockedApplication? = nil
    ) {
        self.id = id
        self.name = name
        self.steps = steps
        self.runCount = runCount
        self.lockedApplication = lockedApplication
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
