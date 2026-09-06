import SwiftUI

/// Chi tiết một Bước: hai picker tách bạch cho **Hành động** và **Vị trí**, đúng theo mô hình
/// trực giao (UI-10, ADR-0002).
struct StepDetailView: View {
    @Binding var step: Step
    let onPickPoint: () -> Void

    var body: some View {
        Form {
            Section("Hành động") {
                Picker("Loại", selection: actionKind) {
                    ForEach(ActionKind.allCases) { Text($0.title).tag($0) }
                }

                switch step.action {
                case .click(_, let count, let hold):
                    Picker("Nút", selection: clickButton) {
                        ForEach(MouseButton.allCases) { Text(StepSummary.name(of: $0)).tag($0) }
                    }
                    labelledField("Số lần bấm", value: clickCount, range: ScenarioLimits.clickCount)
                    labelledField("Giữ", value: clickHold, range: ScenarioLimits.holdMilliseconds, suffix: "ms")
                    if count == 2 {
                        footnote("Hai lần bấm liền nhau được đánh dấu là double click, không phải hai click rời.")
                    }
                    if hold > 0 {
                        footnote("Con trỏ đứng yên trong lúc giữ. Dừng giữa chừng vẫn nhả nút.")
                    }

                case .scroll:
                    labelledField("Ngang", value: scrollDeltaX, range: ScenarioLimits.scrollDelta, suffix: "dòng")
                    labelledField("Dọc", value: scrollDeltaY, range: ScenarioLimits.scrollDelta, suffix: "dòng")
                    footnote("Dọc dương là cuộn lên.")

                case .move:
                    footnote("Chỉ đưa con trỏ tới vị trí, không bấm gì.")
                }
            }

            Section("Vị trí") {
                Picker("Loại", selection: targetKind) {
                    ForEach(TargetKind.allCases) { Text($0.title).tag($0) }
                }

                switch step.target {
                case .cursor:
                    footnote("Đọc lại vị trí con trỏ ở mỗi lần lặp, nên chuỗi thao tác sẽ đi theo tay bạn.")
                case let .screenPoint(x, y):
                    HStack {
                        Text("Toạ độ")
                        Spacer()
                        Text("X: \(Int(x.rounded()))  Y: \(Int(y.rounded()))")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        Button("Chọn điểm…", action: onPickPoint)
                    }
                }
            }

            Section("Lặp và chờ") {
                labelledField("Lặp bước", value: $step.repeatCount, range: ScenarioLimits.stepRepeatCount, suffix: "lần")
                labelledField(
                    "Chờ sau mỗi lần",
                    value: $step.delayMillisecondsAfter,
                    range: ScenarioLimits.delayMilliseconds,
                    suffix: "ms"
                )
                if step.delayMillisecondsAfter < ScenarioLimits.minimumEventGapMilliseconds {
                    footnote("Bộ chạy luôn nhường ít nhất \(ScenarioLimits.minimumEventGapMilliseconds) ms giữa hai sự kiện.")
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Cầu nối giữa picker và mô hình

    private enum ActionKind: String, CaseIterable, Identifiable {
        case click, scroll, move
        var id: String { rawValue }
        var title: String {
            switch self {
            case .click: return "Click / giữ nhấn"
            case .scroll: return "Cuộn"
            case .move: return "Di chuột"
            }
        }
    }

    private enum TargetKind: String, CaseIterable, Identifiable {
        case cursor, screenPoint
        var id: String { rawValue }
        var title: String {
            switch self {
            case .cursor: return "Theo con trỏ"
            case .screenPoint: return "Điểm cố định"
            }
        }
    }

    private var actionKind: Binding<ActionKind> {
        Binding(
            get: {
                switch step.action {
                case .click: return .click
                case .scroll: return .scroll
                case .move: return .move
                }
            },
            set: { kind in
                switch kind {
                case .click:
                    if case .click = step.action { return }
                    step.action = .click(button: .left, count: 1, holdMilliseconds: 0)
                case .scroll:
                    if case .scroll = step.action { return }
                    step.action = .scroll(deltaX: 0, deltaY: -3)
                case .move:
                    step.action = .move
                }
            }
        )
    }

    private var targetKind: Binding<TargetKind> {
        Binding(
            get: {
                switch step.target {
                case .cursor: return .cursor
                case .screenPoint: return .screenPoint
                }
            },
            set: { kind in
                switch kind {
                case .cursor:
                    step.target = .cursor
                case .screenPoint:
                    if case .screenPoint = step.target { return }
                    step.target = .screenPoint(x: 0, y: 0)
                }
            }
        )
    }

    private var clickButton: Binding<MouseButton> {
        Binding(
            get: {
                guard case let .click(button, _, _) = step.action else { return .left }
                return button
            },
            set: { newValue in
                guard case let .click(_, count, hold) = step.action else { return }
                step.action = .click(button: newValue, count: count, holdMilliseconds: hold)
            }
        )
    }

    private var clickCount: Binding<Int> {
        Binding(
            get: {
                guard case let .click(_, count, _) = step.action else { return 1 }
                return count
            },
            set: { newValue in
                guard case let .click(button, _, hold) = step.action else { return }
                step.action = .click(button: button, count: newValue, holdMilliseconds: hold)
            }
        )
    }

    private var clickHold: Binding<Int> {
        Binding(
            get: {
                guard case let .click(_, _, hold) = step.action else { return 0 }
                return hold
            },
            set: { newValue in
                guard case let .click(button, count, _) = step.action else { return }
                step.action = .click(button: button, count: count, holdMilliseconds: newValue)
            }
        )
    }

    private var scrollDeltaX: Binding<Int> {
        Binding(
            get: {
                guard case let .scroll(deltaX, _) = step.action else { return 0 }
                return deltaX
            },
            set: { newValue in
                guard case let .scroll(_, deltaY) = step.action else { return }
                step.action = .scroll(deltaX: newValue, deltaY: deltaY)
            }
        )
    }

    private var scrollDeltaY: Binding<Int> {
        Binding(
            get: {
                guard case let .scroll(_, deltaY) = step.action else { return 0 }
                return deltaY
            },
            set: { newValue in
                guard case let .scroll(deltaX, _) = step.action else { return }
                step.action = .scroll(deltaX: deltaX, deltaY: newValue)
            }
        )
    }

    // MARK: - Thành phần dùng lại

    private func labelledField(
        _ title: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        suffix: String? = nil
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField(
                "",
                value: Binding(
                    get: { value.wrappedValue },
                    set: { value.wrappedValue = $0.clamped(to: range) }
                ),
                format: .number
            )
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.trailing)
            .frame(width: 90)
            if let suffix {
                Text(suffix)
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .leading)
            }
        }
    }

    private func footnote(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
