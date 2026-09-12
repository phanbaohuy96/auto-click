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

    /// Số đơn vị UTF-16 tối đa gửi trong một cặp phím khi gõ chuỗi (EX-24).
    static let typingChunkUTF16Units = 20

    /// Số điểm trung gian khi kéo thả (EX-20). Nhiều ứng dụng bỏ qua thao tác kéo nếu con trỏ
    /// nhảy thẳng từ đầu tới cuối mà không có điểm nào ở giữa.
    static let dragIntermediateSteps = 24
    static let dragStepGapMilliseconds = 8

    /// Thời gian tối đa chờ Ứng dụng khoá lên trước khi gõ phím (SF-4).
    static let activationTimeoutMilliseconds = 500

    static let recognitionThreshold = 0.50...1.0
    static let recognitionWaitMilliseconds = 0...600_000
    /// Nhịp thử lại tối thiểu khi giải Vị trí theo Ảnh mẫu, để không đốt CPU (EX-8).
    static let recognitionRetryFloorMilliseconds = 150
    static let defaultRecognitionThreshold = 0.90
}

/// Việc phải làm khi hết thời gian chờ mà vẫn không tìm thấy mục tiêu (DM-16).
enum TimeoutBehaviour: String, CaseIterable, Identifiable, Codable, Sendable {
    case stopScenario
    case skipStep

    var id: String { rawValue }
}

/// Phần màn hình được thu hẹp để tìm mục tiêu (DM-17).
///
/// Không bao giờ đòi hỏi **Ứng dụng khoá**: xem [ADR-0006]. Dạng tương đối cửa sổ bền hơn nên
/// được ưu tiên khi khoanh, nhưng khi chạy mà không giải được thì lùi về phạm vi mặc định
/// thay vì báo lỗi.
enum SearchRegion: Equatable, Sendable {
    case screenRect(x: Double, y: Double, width: Double, height: Double)
    case windowRelative(
        corner: WindowCorner,
        dx: Double,
        dy: Double,
        width: Double,
        height: Double
    )
}

struct RecognitionSettings: Equatable, Sendable {
    var threshold: Double
    var searchRegion: SearchRegion?
    var waitMilliseconds: Int
    var onTimeout: TimeoutBehaviour

    init(
        threshold: Double = ScenarioLimits.defaultRecognitionThreshold,
        searchRegion: SearchRegion? = nil,
        waitMilliseconds: Int = 0,
        onTimeout: TimeoutBehaviour = .stopScenario
    ) {
        self.threshold = threshold.clamped(to: ScenarioLimits.recognitionThreshold)
        self.searchRegion = searchRegion
        self.waitMilliseconds = waitMilliseconds
            .clamped(to: ScenarioLimits.recognitionWaitMilliseconds)
        self.onTimeout = onTimeout
    }
}

/// Góc của Cửa sổ neo mà một Vị trí tương đối bám vào (DM-13).
///
/// Góc được chọn tự động lúc ghi điểm — góc gần điểm nhất — nên nút ở góc phải-dưới vẫn đúng
/// khi cửa sổ được phóng to, thứ mà neo cố định vào góc trên-trái không làm được.
enum WindowCorner: String, CaseIterable, Identifiable, Codable, Sendable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    var id: String { rawValue }
}

enum KeyModifier: String, CaseIterable, Identifiable, Codable, Sendable {
    case command
    case option
    case control
    case shift

    var id: String { rawValue }
}

/// Một tổ hợp phím. Tên phím được lưu dưới dạng chuỗi đọc được chứ không phải mã số (DM-21).
struct KeyStroke: Equatable, Codable, Sendable {
    var key: String
    var modifiers: [KeyModifier]

    init(key: String, modifiers: [KeyModifier] = []) {
        self.key = key
        // Chuẩn hoá để hai tổ hợp giống nhau luôn so sánh bằng nhau và luôn ghi ra cùng một JSON.
        self.modifiers = Array(Set(modifiers)).sorted { $0.rawValue < $1.rawValue }
    }
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
    /// Nhấn giữ tại Vị trí của Bước, kéo qua các điểm trung gian, nhả tại `destination` (DM-9).
    case drag(button: MouseButton, destination: StepTarget)
    case typeText(String)
    case pressKey(KeyStroke)

    /// Sự kiện bàn phím không mang toạ độ nên `EX-10` không bảo vệ được nó; xem `SF-4`.
    var isKeyboard: Bool {
        switch self {
        case .typeText, .pressKey: return true
        case .click, .scroll, .move, .drag: return false
        }
    }
}

/// Nơi một Hành động diễn ra, chỉ giải ra toạ độ lúc chạy (DM-11, DM-12).
indirect enum StepTarget: Equatable, Sendable {
    case cursor
    case screenPoint(x: Double, y: Double)
    /// Lệch so với một góc của Cửa sổ neo (DM-13). Chỉ giải được khi có Ứng dụng khoá (DM-18).
    case windowRelative(corner: WindowCorner, dx: Double, dy: Double)
    /// Tâm của Ảnh mẫu tìm thấy trên màn hình (DM-14).
    case template(name: String, settings: RecognitionSettings)
    /// Tâm của đoạn chữ tìm thấy trên màn hình (DM-15).
    case text(String, settings: RecognitionSettings)

    /// Chỉ `windowRelative` mới **bắt buộc** phải có Cửa sổ neo. Ảnh mẫu và chữ thì không —
    /// xem [ADR-0006].
    var needsAnchorWindow: Bool {
        if case .windowRelative = self { return true }
        return false
    }

    /// Cấu hình nhận dạng, nếu Vị trí này phải đi tìm mục tiêu.
    var recognitionSettings: RecognitionSettings? {
        switch self {
        case let .template(_, settings), let .text(_, settings): return settings
        case .cursor, .screenPoint, .windowRelative: return nil
        }
    }

    /// Tên tệp Ảnh mẫu mà Vị trí này cần, nếu có.
    var templateName: String? {
        if case let .template(name, _) = self { return name }
        return nil
    }
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
    /// Tiêu đề của **Cửa sổ neo** lúc ghi, nếu biết.
    ///
    /// Bundle id một mình không đủ để chỉ ra một cửa sổ: hai hồ sơ Chrome là hai tiến trình cùng
    /// bundle id, và một tiến trình thì có bao nhiêu cửa sổ tuỳ thích. Không có tiêu đề, lúc chạy
    /// lại Kịch bản bám vào "tiến trình đầu tiên khớp bundle id, cửa sổ đang focus của nó" — tức
    /// là cửa sổ nào tình cờ ở trước. Phát hiện lúc chuẩn bị `D10` của kiểm thử tay: một bản ghi
    /// dựng trên cửa sổ nháp suýt chạy lại lên cửa sổ đang đăng nhập của người dùng.
    ///
    /// Chỉ là **ưu tiên**, không phải điều kiện cứng: tiêu đề cửa sổ đổi suốt (mở tệp khác, đổi
    /// tab), nên không khớp thì vẫn lùi về cách cũ chứ không từ chối chạy.
    var windowTitle: String?

    init(bundleIdentifier: String, name: String, windowTitle: String? = nil) {
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.windowTitle = windowTitle
    }
}

extension Step {
    /// Mọi Vị trí mà Bước này chạm tới, kể cả đích của thao tác kéo thả.
    var targets: [StepTarget] {
        if case let .drag(_, destination) = action { return [target, destination] }
        return [target]
    }
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

    /// DM-18: Vị trí tương đối cửa sổ không giải được nếu thiếu Ứng dụng khoá.
    var requiresLockedApplication: Bool {
        steps.contains { $0.targets.contains(where: \.needsAnchorWindow) }
    }

    /// Tên các tệp Ảnh mẫu mà Kịch bản này dùng tới.
    var templateNames: Set<String> {
        Set(steps.flatMap(\.targets).compactMap(\.templateName))
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
