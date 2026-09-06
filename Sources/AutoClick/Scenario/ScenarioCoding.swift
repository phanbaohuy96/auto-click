import Foundation

/// Mã hoá Kịch bản sang JSON đọc và sửa tay được (ST-5, ST-6, ST-7).
///
/// Không dùng Codable tổng hợp sẵn cho enum có giá trị đi kèm: nó sinh ra JSON lồng theo tên
/// `case` của Swift, nghĩa là đổi tên một `case` trong code sẽ âm thầm làm hỏng mọi file đã lưu.
/// Trường phân biệt `kind` tách định dạng trên đĩa khỏi tên trong code.
enum ScenarioSchema {
    static let currentVersion = 1
}

enum ScenarioDecodingError: LocalizedError, Equatable {
    case unsupportedSchemaVersion(Int)
    case unknownActionKind(String)
    case unknownTargetKind(String)

    var errorDescription: String? {
        switch self {
        case let .unsupportedSchemaVersion(version):
            return "Kịch bản dùng định dạng phiên bản \(version), bản Auto Click này chỉ hiểu tới \(ScenarioSchema.currentVersion)."
        case let .unknownActionKind(kind):
            return "Không nhận ra hành động \"\(kind)\"."
        case let .unknownTargetKind(kind):
            return "Không nhận ra vị trí \"\(kind)\"."
        }
    }
}

/// Phần đầu của `scenario.json` đọc được kể cả khi phần còn lại thuộc định dạng mới hơn (ST-12).
struct ScenarioHeader: Decodable {
    let schemaVersion: Int
    let id: UUID
    let name: String
}

// MARK: - RunCount

extension RunCount: Codable {
    private static let untilStoppedToken = "until-stopped"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let count = try? container.decode(Int.self) {
            self = .times(count.clamped(to: ScenarioLimits.runCount))
            return
        }
        let token = try container.decode(String.self)
        guard token == Self.untilStoppedToken else {
            self = .times(1)
            return
        }
        self = .untilStopped
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .times(count):
            try container.encode(count)
        case .untilStopped:
            try container.encode(Self.untilStoppedToken)
        }
    }
}

// MARK: - StepAction

extension StepAction: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind, button, count, holdMilliseconds, deltaX, deltaY
    }

    private enum Kind: String {
        case click, scroll, move
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawKind = try container.decode(String.self, forKey: .kind)
        guard let kind = Kind(rawValue: rawKind) else {
            throw ScenarioDecodingError.unknownActionKind(rawKind)
        }

        switch kind {
        case .click:
            self = .click(
                button: try container.decodeIfPresent(MouseButton.self, forKey: .button) ?? .left,
                count: (try container.decodeIfPresent(Int.self, forKey: .count) ?? 1)
                    .clamped(to: ScenarioLimits.clickCount),
                holdMilliseconds: (try container.decodeIfPresent(Int.self, forKey: .holdMilliseconds) ?? 0)
                    .clamped(to: ScenarioLimits.holdMilliseconds)
            )
        case .scroll:
            self = .scroll(
                deltaX: (try container.decodeIfPresent(Int.self, forKey: .deltaX) ?? 0)
                    .clamped(to: ScenarioLimits.scrollDelta),
                deltaY: (try container.decodeIfPresent(Int.self, forKey: .deltaY) ?? 0)
                    .clamped(to: ScenarioLimits.scrollDelta)
            )
        case .move:
            self = .move
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .click(button, count, holdMilliseconds):
            try container.encode(Kind.click.rawValue, forKey: .kind)
            try container.encode(button, forKey: .button)
            try container.encode(count, forKey: .count)
            try container.encode(holdMilliseconds, forKey: .holdMilliseconds)
        case let .scroll(deltaX, deltaY):
            try container.encode(Kind.scroll.rawValue, forKey: .kind)
            try container.encode(deltaX, forKey: .deltaX)
            try container.encode(deltaY, forKey: .deltaY)
        case .move:
            try container.encode(Kind.move.rawValue, forKey: .kind)
        }
    }
}

// MARK: - StepTarget

extension StepTarget: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind, x, y
    }

    private enum Kind: String {
        case cursor
        case screenPoint
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawKind = try container.decode(String.self, forKey: .kind)
        guard let kind = Kind(rawValue: rawKind) else {
            throw ScenarioDecodingError.unknownTargetKind(rawKind)
        }

        switch kind {
        case .cursor:
            self = .cursor
        case .screenPoint:
            self = .screenPoint(
                x: try container.decodeIfPresent(Double.self, forKey: .x) ?? 0,
                y: try container.decodeIfPresent(Double.self, forKey: .y) ?? 0
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .cursor:
            try container.encode(Kind.cursor.rawValue, forKey: .kind)
        case let .screenPoint(x, y):
            try container.encode(Kind.screenPoint.rawValue, forKey: .kind)
            try container.encode(x, forKey: .x)
            try container.encode(y, forKey: .y)
        }
    }
}

// MARK: - Step

extension Step: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, action, target
        case repeatCount = "repeat"
        case delayMillisecondsAfter
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
            action: try container.decode(StepAction.self, forKey: .action),
            target: try container.decode(StepTarget.self, forKey: .target),
            repeatCount: try container.decodeIfPresent(Int.self, forKey: .repeatCount) ?? 1,
            delayMillisecondsAfter: try container.decodeIfPresent(
                Int.self,
                forKey: .delayMillisecondsAfter
            ) ?? 0
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(action, forKey: .action)
        try container.encode(target, forKey: .target)
        try container.encode(repeatCount, forKey: .repeatCount)
        try container.encode(delayMillisecondsAfter, forKey: .delayMillisecondsAfter)
    }
}

// MARK: - Scenario

extension Scenario: Codable {
    private enum CodingKeys: String, CodingKey {
        case schemaVersion, id, name, steps, lockedApplication
        case runCount = "repeat"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decodeIfPresent(Int.self, forKey: .schemaVersion)
            ?? ScenarioSchema.currentVersion
        guard version <= ScenarioSchema.currentVersion else {
            throw ScenarioDecodingError.unsupportedSchemaVersion(version)
        }

        self.init(
            id: try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
            name: try container.decodeIfPresent(String.self, forKey: .name) ?? "Kịch bản",
            steps: try container.decodeIfPresent([Step].self, forKey: .steps) ?? [],
            runCount: try container.decodeIfPresent(RunCount.self, forKey: .runCount) ?? .times(1),
            lockedApplication: try container.decodeIfPresent(
                LockedApplication.self,
                forKey: .lockedApplication
            )
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(ScenarioSchema.currentVersion, forKey: .schemaVersion)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(runCount, forKey: .runCount)
        try container.encodeIfPresent(lockedApplication, forKey: .lockedApplication)
        try container.encode(steps, forKey: .steps)
    }
}
