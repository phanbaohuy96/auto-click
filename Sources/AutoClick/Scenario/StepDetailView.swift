import AppKit
import CoreGraphics
import SwiftUI

/// Chi tiết một Bước: hai picker tách bạch cho **Hành động** và **Vị trí**, đúng theo mô hình
/// trực giao (UI-10, ADR-0002).
struct StepDetailView: View {
    @Binding var step: Step
    /// Tên Ứng dụng khoá, hoặc `nil` khi Kịch bản chưa khoá vào ứng dụng nào.
    let lockedApplicationName: String?
    let onPickScreenPoint: (@escaping (CGPoint) -> Void) -> Void
    let onPickWindowOffset: (@escaping (WindowAnchor.Offset) -> Void) -> Void
    let onCaptureTemplate: (@escaping (String, SearchRegion?) -> Void) -> Void
    let onPickSearchRegion: (@escaping (SearchRegion) -> Void) -> Void
    /// Ảnh mẫu đã lưu, để bày thumbnail thay vì tên tệp — tên `3f2a91c0.png` không nói lên gì.
    let templateImage: (String) -> NSImage?

    var body: some View {
        Form {
            Section("Hành động") {
                Picker("Loại", selection: actionKind) {
                    ForEach(ActionKind.allCases) { Text($0.title).tag($0) }
                }
                actionParameters
            }

            Section("Vị trí") {
                targetEditor(target)
            }

            if case .drag = step.action {
                Section("Điểm nhả") {
                    targetEditor(dragDestination)
                }
            }

            Section("Lặp và chờ") {
                labelledField(
                    "Lặp bước",
                    value: $step.repeatCount,
                    range: ScenarioLimits.stepRepeatCount,
                    suffix: "lần"
                )
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

    // MARK: - Tham số của Hành động

    @ViewBuilder
    private var actionParameters: some View {
        switch step.action {
        case .click(_, let count, let hold):
            Picker("Nút", selection: mouseButton) {
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

        case .drag:
            Picker("Nút", selection: mouseButton) {
                ForEach(MouseButton.allCases) { Text(StepSummary.name(of: $0)).tag($0) }
            }
            footnote("Nhấn giữ tại Vị trí, kéo qua \(ScenarioLimits.dragIntermediateSteps) điểm trung gian, rồi nhả tại Điểm nhả.")

        case .typeText:
            TextField("Nội dung", text: typedText, axis: .vertical)
                .lineLimit(1...4)
            footnote("Gõ trực tiếp chuỗi ký tự nên không phụ thuộc bố cục bàn phím; gõ được cả tiếng Việt.")

        case let .pressKey(stroke):
            Picker("Phím", selection: keyName) {
                ForEach(KeyCatalog.entries) { Text($0.title).tag($0.name) }
            }
            HStack {
                Text("Phím bổ trợ")
                Spacer()
                ForEach(KeyModifier.allCases) { modifier in
                    Toggle(modifier.symbol, isOn: modifierBinding(modifier))
                        .toggleStyle(.button)
                }
            }
            footnote("Sẽ gửi \(KeyCatalog.describe(stroke)).")
        }

        if step.action.isKeyboard {
            if let lockedApplicationName {
                footnote("Trước khi gõ, Auto Click đưa \(lockedApplicationName) lên trước; không đưa lên được thì dừng.")
            } else {
                warning("Chưa khoá ứng dụng: phím sẽ đi vào bất kỳ cửa sổ nào đang ở trước.")
            }
        }
    }

    // MARK: - Trình sửa Vị trí

    @ViewBuilder
    private func targetEditor(_ target: Binding<StepTarget>) -> some View {
        Picker("Loại", selection: targetKind(target)) {
            ForEach(TargetKind.allCases) { Text($0.title).tag($0) }
        }

        switch target.wrappedValue {
        case .cursor:
            footnote("Đọc lại vị trí con trỏ ở mỗi lần lặp, nên chuỗi thao tác sẽ đi theo tay bạn.")

        case let .screenPoint(x, y):
            HStack {
                Text("Toạ độ")
                Spacer()
                Text("X: \(Int(x.rounded()))  Y: \(Int(y.rounded()))")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Button("Chọn điểm…") {
                    onPickScreenPoint { point in
                        target.wrappedValue = .screenPoint(x: point.x, y: point.y)
                    }
                }
            }

        case let .windowRelative(corner, dx, dy):
            if let lockedApplicationName {
                HStack {
                    Text("Lệch góc \(corner.title)")
                    Spacer()
                    Text("\(Int(dx.rounded())), \(Int(dy.rounded()))")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Button("Chọn điểm…") {
                        onPickWindowOffset { offset in
                            target.wrappedValue = .windowRelative(
                                corner: offset.corner,
                                dx: offset.dx,
                                dy: offset.dy
                            )
                        }
                    }
                }
                footnote("Bám vào góc gần điểm nhất của cửa sổ trước nhất thuộc \(lockedApplicationName), nên cửa sổ dịch chuyển hay phóng to vẫn đúng.")
            } else {
                warning("Phải khoá kịch bản vào một ứng dụng thì mới neo được theo cửa sổ.")
            }

        case let .template(name, settings):
            HStack(alignment: .top) {
                Text("Ảnh mẫu")
                Spacer()
                templateThumbnail(name)
                Button(name.isEmpty ? "Chụp vùng…" : "Chụp lại…") {
                    onCaptureTemplate { captured, suggestedRegion in
                        target.wrappedValue = .template(
                            name: captured,
                            settings: RecognitionSettings(
                                threshold: settings.threshold,
                                // RG-23: vùng tìm bám theo chỗ vừa chụp. Chụp lại thì vùng đi
                                // theo ảnh mới, vì vùng cũ vốn suy ra từ ảnh cũ.
                                searchRegion: suggestedRegion ?? settings.searchRegion,
                                waitMilliseconds: settings.waitMilliseconds,
                                onTimeout: settings.onTimeout
                            )
                        )
                    }
                }
            }
            footnote("Khoanh được ở bất cứ đâu — kể cả từ một ảnh chụp màn hình đang mở trong ứng dụng khác, khi mục tiêu chưa hiện ra.")
            thresholdField(target, settings: settings)
            recognitionFields(target, settings: settings)

        case let .text(text, settings):
            TextField("Chữ cần tìm", text: Binding(
                get: { text },
                set: { target.wrappedValue = .text($0, settings: settings) }
            ))
            footnote("Không phân biệt hoa thường. Bền hơn ảnh mẫu khi đổi giao diện sáng/tối hay cỡ chữ, nhưng chỉ nhắm được thứ có chữ.")
            recognitionFields(target, settings: settings)
        }
    }

    /// Bày chính Ảnh mẫu thay cho tên tệp: tên là `3f2a91c0.png`, nhìn không biết là cái gì.
    @ViewBuilder
    private func templateThumbnail(_ name: String) -> some View {
        if name.isEmpty {
            Text("Chưa chụp")
                .foregroundStyle(.secondary)
        } else if let image = templateImage(name) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 160, maxHeight: 64)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4).strokeBorder(.separator)
                )
                // Kích thước thật vẫn cần: nó quyết định vùng quét và tốc độ khớp.
                .help("\(name) — \(Int(image.size.width))×\(Int(image.size.height)) pixel")
        } else {
            Label("Thiếu tệp ảnh mẫu", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.caption)
        }
    }

    // MARK: - Cấu hình nhận dạng

    @ViewBuilder
    private func thresholdField(
        _ target: Binding<StepTarget>,
        settings: RecognitionSettings
    ) -> some View {
        HStack {
            Text("Ngưỡng khớp")
            Slider(
                value: Binding(
                    get: { settings.threshold },
                    set: { update(target, settings, threshold: $0) }
                ),
                in: ScenarioLimits.recognitionThreshold
            )
            Text(String(format: "%.2f", settings.threshold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)
        }
    }

    @ViewBuilder
    private func recognitionFields(
        _ target: Binding<StepTarget>,
        settings: RecognitionSettings
    ) -> some View {
        labelledField(
            "Chờ tối đa",
            value: Binding(
                get: { settings.waitMilliseconds },
                set: { update(target, settings, wait: $0) }
            ),
            range: ScenarioLimits.recognitionWaitMilliseconds,
            suffix: "ms"
        )

        Picker(
            "Hết giờ thì",
            selection: Binding(
                get: { settings.onTimeout },
                set: { update(target, settings, onTimeout: $0) }
            )
        ) {
            Text("Dừng kịch bản").tag(TimeoutBehaviour.stopScenario)
            Text("Bỏ qua bước").tag(TimeoutBehaviour.skipStep)
        }

        HStack {
            Text("Vùng tìm")
            Spacer()
            Text(searchRegionDescription(settings.searchRegion))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if settings.searchRegion != nil {
                Button("Bỏ") { update(target, settings, searchRegion: .some(nil)) }
            }
            Button("Khoanh…") {
                onPickSearchRegion { region in
                    update(target, settings, searchRegion: .some(region))
                }
            }
        }
        if settings.waitMilliseconds > 0 {
            footnote("Thử lại tới \(settings.waitMilliseconds) ms — đủ để đợi nút hiện ra sau khi trang tải.")
        }
    }

    private func searchRegionDescription(_ region: SearchRegion?) -> String {
        switch region {
        case nil:
            return "Cả màn hình (hoặc cửa sổ đã khoá)"
        case let .screenRect(_, _, width, height):
            return "Tuyệt đối \(Int(width))×\(Int(height)) — trượt nếu cửa sổ dịch"
        case let .windowRelative(_, _, _, width, height):
            return "Theo cửa sổ \(Int(width))×\(Int(height))"
        }
    }

    private func update(
        _ target: Binding<StepTarget>,
        _ settings: RecognitionSettings,
        threshold: Double? = nil,
        wait: Int? = nil,
        onTimeout: TimeoutBehaviour? = nil,
        searchRegion: SearchRegion?? = nil
    ) {
        let updated = RecognitionSettings(
            threshold: threshold ?? settings.threshold,
            searchRegion: searchRegion ?? settings.searchRegion,
            waitMilliseconds: wait ?? settings.waitMilliseconds,
            onTimeout: onTimeout ?? settings.onTimeout
        )
        switch target.wrappedValue {
        case let .template(name, _):
            target.wrappedValue = .template(name: name, settings: updated)
        case let .text(text, _):
            target.wrappedValue = .text(text, settings: updated)
        default:
            break
        }
    }

    // MARK: - Cầu nối giữa picker và mô hình

    private enum ActionKind: String, CaseIterable, Identifiable {
        case click, scroll, move, drag, typeText, pressKey
        var id: String { rawValue }
        var title: String {
            switch self {
            case .click: return "Click / giữ nhấn"
            case .scroll: return "Cuộn"
            case .move: return "Di chuột"
            case .drag: return "Kéo thả"
            case .typeText: return "Gõ chuỗi"
            case .pressKey: return "Tổ hợp phím"
            }
        }
    }

    private enum TargetKind: String, CaseIterable, Identifiable {
        case cursor, screenPoint, windowRelative, template, text
        var id: String { rawValue }
        var title: String {
            switch self {
            case .cursor: return "Theo con trỏ"
            case .screenPoint: return "Điểm cố định"
            case .windowRelative: return "Lệch theo cửa sổ"
            case .template: return "Theo ảnh mẫu"
            case .text: return "Theo chữ"
            }
        }
    }

    private var target: Binding<StepTarget> { $step.target }

    private var dragDestination: Binding<StepTarget> {
        Binding(
            get: {
                guard case let .drag(_, destination) = step.action else { return .cursor }
                return destination
            },
            set: { newValue in
                guard case let .drag(button, _) = step.action else { return }
                step.action = .drag(button: button, destination: newValue)
            }
        )
    }

    private var actionKind: Binding<ActionKind> {
        Binding(
            get: {
                switch step.action {
                case .click: return .click
                case .scroll: return .scroll
                case .move: return .move
                case .drag: return .drag
                case .typeText: return .typeText
                case .pressKey: return .pressKey
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
                case .drag:
                    if case .drag = step.action { return }
                    step.action = .drag(button: .left, destination: .cursor)
                case .typeText:
                    if case .typeText = step.action { return }
                    step.action = .typeText("")
                case .pressKey:
                    if case .pressKey = step.action { return }
                    step.action = .pressKey(KeyStroke(key: "return"))
                }
            }
        )
    }

    private func targetKind(_ target: Binding<StepTarget>) -> Binding<TargetKind> {
        Binding(
            get: {
                switch target.wrappedValue {
                case .cursor: return .cursor
                case .screenPoint: return .screenPoint
                case .windowRelative: return .windowRelative
                case .template: return .template
                case .text: return .text
                }
            },
            set: { kind in
                switch kind {
                case .cursor:
                    target.wrappedValue = .cursor
                case .screenPoint:
                    if case .screenPoint = target.wrappedValue { return }
                    target.wrappedValue = .screenPoint(x: 0, y: 0)
                case .windowRelative:
                    if case .windowRelative = target.wrappedValue { return }
                    target.wrappedValue = .windowRelative(corner: .topLeft, dx: 0, dy: 0)
                case .template:
                    if case .template = target.wrappedValue { return }
                    target.wrappedValue = .template(
                        name: "",
                        settings: target.wrappedValue.recognitionSettings ?? RecognitionSettings()
                    )
                case .text:
                    if case .text = target.wrappedValue { return }
                    target.wrappedValue = .text(
                        "",
                        settings: target.wrappedValue.recognitionSettings ?? RecognitionSettings()
                    )
                }
            }
        )
    }

    private var mouseButton: Binding<MouseButton> {
        Binding(
            get: {
                switch step.action {
                case let .click(button, _, _): return button
                case let .drag(button, _): return button
                default: return .left
                }
            },
            set: { newValue in
                switch step.action {
                case let .click(_, count, hold):
                    step.action = .click(button: newValue, count: count, holdMilliseconds: hold)
                case let .drag(_, destination):
                    step.action = .drag(button: newValue, destination: destination)
                default:
                    break
                }
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

    private var typedText: Binding<String> {
        Binding(
            get: {
                guard case let .typeText(text) = step.action else { return "" }
                return text
            },
            set: { step.action = .typeText($0) }
        )
    }

    private var keyName: Binding<String> {
        Binding(
            get: {
                guard case let .pressKey(stroke) = step.action else { return "return" }
                return stroke.key
            },
            set: { newValue in
                guard case let .pressKey(stroke) = step.action else { return }
                step.action = .pressKey(KeyStroke(key: newValue, modifiers: stroke.modifiers))
            }
        )
    }

    private func modifierBinding(_ modifier: KeyModifier) -> Binding<Bool> {
        Binding(
            get: {
                guard case let .pressKey(stroke) = step.action else { return false }
                return stroke.modifiers.contains(modifier)
            },
            set: { isOn in
                guard case let .pressKey(stroke) = step.action else { return }
                var modifiers = stroke.modifiers
                if isOn {
                    modifiers.append(modifier)
                } else {
                    modifiers.removeAll { $0 == modifier }
                }
                step.action = .pressKey(KeyStroke(key: stroke.key, modifiers: modifiers))
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

    private func warning(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true)
    }
}

extension WindowCorner {
    var title: String {
        switch self {
        case .topLeft: return "trên-trái"
        case .topRight: return "trên-phải"
        case .bottomLeft: return "dưới-trái"
        case .bottomRight: return "dưới-phải"
        }
    }
}
