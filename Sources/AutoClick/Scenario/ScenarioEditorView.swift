import AppKit
import SwiftUI

/// Bề mặt **cấu hình** (UI-2). Popover trên menu bar không chứa trình sửa Bước.
struct ScenarioEditorView: View {
    @ObservedObject var store: ScenarioStore
    @ObservedObject var runner: ScenarioRunner

    @State private var selectedStepID: UUID?
    @State private var pointSelector: ClickPointSelector?
    @State private var pickError: String?
    @State private var runningApplications: [RunningApplicationOption] = []
    @State private var captureCoordinator = TemplateCaptureCoordinator()

    var body: some View {
        VStack(spacing: 0) {
            scenarioBar
                .padding(12)
            Divider()

            if let scenario = store.selectedScenario {
                if store.isReadOnly(scenario) {
                    readOnlyNotice(scenario)
                } else {
                    editor(for: store.binding(for: scenario.id))
                }
            } else {
                emptyState
            }
        }
        .frame(minWidth: 760, minHeight: 460)
        .onAppear { runningApplications = RunningApplicationOption.current() }
        .disabled(runner.isRunning)
        .overlay(alignment: .top) {
            if runner.isRunning {
                Label("Đang chạy — không sửa được", systemImage: "lock.fill")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.top, 8)
            }
        }
    }

    // MARK: - Thanh kịch bản

    private var scenarioBar: some View {
        HStack(spacing: 10) {
            Picker("Kịch bản", selection: $store.selectedScenarioID) {
                if store.scenarios.isEmpty {
                    Text("Chưa có kịch bản").tag(UUID?.none)
                }
                ForEach(store.scenarios) { scenario in
                    Text(scenario.name).tag(UUID?.some(scenario.id))
                }
            }
            .labelsHidden()
            .frame(width: 220)

            Button { store.create() } label: { Image(systemName: "plus") }
                .help("Kịch bản mới")

            Button {
                if let scenario = store.selectedScenario { store.duplicate(scenario) }
            } label: { Image(systemName: "doc.on.doc") }
                .disabled(store.selectedScenario == nil)
                .help("Nhân bản")

            Button {
                if let scenario = store.selectedScenario { store.delete(scenario) }
            } label: { Image(systemName: "trash") }
                .disabled(store.selectedScenario == nil)
                .help("Xoá kịch bản và toàn bộ thư mục của nó")

            Spacer()

            if !store.loadIssues.isEmpty {
                Label("\(store.loadIssues.count) kịch bản có vấn đề", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .help(store.loadIssues.joined(separator: "\n"))
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text("Chưa có kịch bản nào")
                .font(.headline)
            Button("Tạo kịch bản đầu tiên") { store.create() }
                .buttonStyle(.borderedProminent)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func readOnlyNotice(_ scenario: Scenario) -> some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "lock.doc")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text("“\(scenario.name)” dùng định dạng mới hơn")
                .font(.headline)
            Text("Chỉ xem được, không sửa và không chạy được bằng bản Auto Click này.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Trình soạn thảo

    private func editor(for scenario: Binding<Scenario>) -> some View {
        VStack(spacing: 0) {
            scenarioSettings(scenario)
                .padding(12)
            Divider()

            HSplitView {
                stepList(scenario)
                    .frame(minWidth: 280, idealWidth: 320)
                stepDetail(scenario)
                    .frame(minWidth: 320)
            }
        }
    }

    private func scenarioSettings(_ scenario: Binding<Scenario>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 16) {
                TextField("Tên kịch bản", text: scenario.name)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 240)

                Toggle("Lặp đến khi dừng", isOn: Binding(
                    get: { scenario.wrappedValue.runCount == .untilStopped },
                    set: { scenario.wrappedValue.runCount = $0 ? .untilStopped : .times(1) }
                ))

                if case let .times(count) = scenario.wrappedValue.runCount {
                    HStack(spacing: 6) {
                        Text("Số vòng")
                        integerField(
                            value: Binding(
                                get: { count },
                                set: { scenario.wrappedValue.runCount = .times($0) }
                            ),
                            range: ScenarioLimits.runCount
                        )
                    }
                }

                Spacer()
            }

            HStack(spacing: 10) {
                Toggle("Khoá vào ứng dụng", isOn: lockToggle(scenario))

                if scenario.wrappedValue.lockedApplication != nil {
                    Picker("Ứng dụng", selection: lockedBundleIdentifier(scenario)) {
                        Text("Chọn ứng dụng…").tag("")
                        ForEach(runningApplications) { Text($0.name).tag($0.bundleIdentifier) }
                    }
                    .labelsHidden()
                    .frame(width: 220)

                    Button {
                        runningApplications = RunningApplicationOption.current()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Làm mới danh sách ứng dụng")
                }

                if let error = runner.validate(scenario.wrappedValue)?.errorDescription {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Spacer()
            }

            if let pickError {
                Label(pickError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func lockToggle(_ scenario: Binding<Scenario>) -> Binding<Bool> {
        Binding(
            get: { scenario.wrappedValue.lockedApplication != nil },
            set: { isOn in
                scenario.wrappedValue.lockedApplication = isOn
                    ? LockedApplication(bundleIdentifier: "", name: "Chưa chọn")
                    : nil
            }
        )
    }

    private func lockedBundleIdentifier(_ scenario: Binding<Scenario>) -> Binding<String> {
        Binding(
            get: { scenario.wrappedValue.lockedApplication?.bundleIdentifier ?? "" },
            set: { bundleIdentifier in
                let name = runningApplications
                    .first { $0.bundleIdentifier == bundleIdentifier }?.name ?? "Chưa chọn"
                scenario.wrappedValue.lockedApplication = LockedApplication(
                    bundleIdentifier: bundleIdentifier,
                    name: name
                )
            }
        )
    }

    private func stepList(_ scenario: Binding<Scenario>) -> some View {
        VStack(spacing: 0) {
            List(selection: $selectedStepID) {
                ForEach(Array(scenario.wrappedValue.steps.enumerated()), id: \.element.id) { index, step in
                    stepRow(index: index, step: step)
                        .tag(step.id)
                }
                .onMove { offsets, destination in
                    scenario.wrappedValue.steps.move(fromOffsets: offsets, toOffset: destination)
                }
                .onDelete { offsets in
                    scenario.wrappedValue.steps.remove(atOffsets: offsets)
                }
            }

            Divider()

            HStack(spacing: 8) {
                Button { addStep(to: scenario) } label: { Image(systemName: "plus") }
                    .help("Thêm bước")

                Button { duplicateSelectedStep(in: scenario) } label: { Image(systemName: "doc.on.doc") }
                    .disabled(selectedStepIndex(in: scenario.wrappedValue) == nil)
                    .help("Nhân bản bước")

                Button { deleteSelectedStep(in: scenario) } label: { Image(systemName: "minus") }
                    .disabled(selectedStepIndex(in: scenario.wrappedValue) == nil)
                    .help("Xoá bước")

                Spacer()
                Text("Kéo để đổi thứ tự")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
        }
    }

    /// Tóm tắt một Bước trên đúng một dòng (UI-8).
    private func stepRow(index: Int, step: Step) -> some View {
        HStack(spacing: 10) {
            Text("\(index + 1)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 22, alignment: .trailing)

            VStack(alignment: .leading, spacing: 2) {
                Text(StepSummary.action(step.action))
                    .lineLimit(1)
                Text(StepSummary.target(step.target))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if step.repeatCount > 1 {
                    Text("×\(step.repeatCount)").font(.caption.monospacedDigit())
                }
                if step.delayMillisecondsAfter > 0 {
                    Text("\(step.delayMillisecondsAfter) ms")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func stepDetail(_ scenario: Binding<Scenario>) -> some View {
        if let index = selectedStepIndex(in: scenario.wrappedValue) {
            StepDetailView(
                step: scenario.steps[index],
                lockedApplicationName: lockedApplicationName(of: scenario.wrappedValue),
                onPickScreenPoint: { apply in pickPoint { point, _ in apply(point) } },
                onPickWindowOffset: { apply in
                    pickWindowOffset(in: scenario.wrappedValue, apply: apply)
                },
                onCaptureTemplate: { apply in
                    captureTemplate(for: scenario.wrappedValue, apply: apply)
                },
                onPickSearchRegion: { apply in
                    pickSearchRegion(in: scenario.wrappedValue, apply: apply)
                }
            )
        } else {
            VStack {
                Spacer()
                Text("Chọn một bước để sửa")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Thao tác

    private func selectedStepIndex(in scenario: Scenario) -> Int? {
        guard let selectedStepID else { return nil }
        return scenario.steps.firstIndex { $0.id == selectedStepID }
    }

    private func addStep(to scenario: Binding<Scenario>) {
        let step = Step(
            action: .click(button: .left, count: 1, holdMilliseconds: 0),
            target: .cursor,
            repeatCount: 1,
            delayMillisecondsAfter: 100
        )
        scenario.wrappedValue.steps.append(step)
        selectedStepID = step.id
    }

    private func duplicateSelectedStep(in scenario: Binding<Scenario>) {
        guard let index = selectedStepIndex(in: scenario.wrappedValue) else { return }
        var copy = scenario.wrappedValue.steps[index]
        copy.id = UUID()
        scenario.wrappedValue.steps.insert(copy, at: index + 1)
        selectedStepID = copy.id
    }

    private func deleteSelectedStep(in scenario: Binding<Scenario>) {
        guard let index = selectedStepIndex(in: scenario.wrappedValue) else { return }
        scenario.wrappedValue.steps.remove(at: index)
        selectedStepID = scenario.wrappedValue.steps.indices.contains(index)
            ? scenario.wrappedValue.steps[index].id
            : scenario.wrappedValue.steps.last?.id
    }

    private func lockedApplicationName(of scenario: Scenario) -> String? {
        guard let locked = scenario.lockedApplication, !locked.bundleIdentifier.isEmpty else {
            return nil
        }
        return locked.name
    }

    /// Lớp phủ chọn điểm phải chạy từ cửa sổ này, không phải từ popover (UI-4).
    private func pickPoint(_ completion: @escaping (CGPoint, NSWindow?) -> Void) {
        let window = NSApp.keyWindow
        window?.orderOut(nil)
        pickError = nil

        let selector = ClickPointSelector()
        pointSelector = selector
        selector.start { point in
            pointSelector = nil
            NSApp.activate(ignoringOtherApps: true)
            window?.makeKeyAndOrderFront(nil)
            guard let point else { return }
            completion(point, window)
        }
    }

    /// Quy điểm vừa chọn về độ lệch so với góc gần nhất của Cửa sổ neo (DM-13).
    private func pickWindowOffset(
        in scenario: Scenario,
        apply: @escaping (WindowAnchor.Offset) -> Void
    ) {
        guard let locked = scenario.lockedApplication, !locked.bundleIdentifier.isEmpty else {
            pickError = "Hãy chọn ứng dụng khoá trước khi neo theo cửa sổ."
            return
        }

        pickPoint { point, _ in
            guard let processIdentifier = RunningApplicationOption.processIdentifier(
                forBundleIdentifier: locked.bundleIdentifier
            ) else {
                pickError = "\(locked.name) hiện không chạy."
                return
            }
            guard let frame = WindowAnchor.focusedWindowFrame(ofProcess: processIdentifier) else {
                pickError = "Không lấy được cửa sổ nào của \(locked.name)."
                return
            }
            apply(WindowAnchor.offset(for: point, in: frame))
        }
    }

    /// RG-4: chụp Ảnh mẫu độc lập hoàn toàn với Ứng dụng khoá.
    private func captureTemplate(for scenario: Scenario, apply: @escaping (String) -> Void) {
        let window = NSApp.keyWindow
        window?.orderOut(nil)
        pickError = nil

        Task {
            defer {
                NSApp.activate(ignoringOtherApps: true)
                window?.makeKeyAndOrderFront(nil)
            }
            do {
                let library = store.templateLibrary(for: scenario.id)
                if let name = try await captureCoordinator.captureTemplate(into: library) {
                    apply(name)
                }
            } catch {
                pickError = error.localizedDescription
            }
        }
    }

    /// RG-6: vùng tìm lưu tương đối Cửa sổ neo khi có sẵn, ngược lại lưu tuyệt đối — và nói rõ
    /// điều đó trên giao diện. Không bao giờ bắt buộc phải khoá ứng dụng ([ADR-0006]).
    private func pickSearchRegion(in scenario: Scenario, apply: @escaping (SearchRegion) -> Void) {
        let window = NSApp.keyWindow
        window?.orderOut(nil)
        pickError = nil

        Task {
            defer {
                NSApp.activate(ignoringOtherApps: true)
                window?.makeKeyAndOrderFront(nil)
            }
            guard let rect = await captureCoordinator.selectRegion(
                prompt: "Kéo để chọn vùng tìm  •  Esc để hủy"
            ) else { return }

            if let locked = scenario.lockedApplication,
               let processIdentifier = RunningApplicationOption.processIdentifier(
                   forBundleIdentifier: locked.bundleIdentifier
               ),
               let frame = WindowAnchor.focusedWindowFrame(ofProcess: processIdentifier) {
                let offset = WindowAnchor.offset(for: rect.origin, in: frame)
                apply(
                    .windowRelative(
                        corner: offset.corner,
                        dx: offset.dx,
                        dy: offset.dy,
                        width: rect.width,
                        height: rect.height
                    )
                )
            } else {
                apply(
                    .screenRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height)
                )
            }
        }
    }

    private func integerField(value: Binding<Int>, range: ClosedRange<Int>) -> some View {
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
    }
}

/// Chuỗi tóm tắt dùng chung giữa danh sách Bước và các thông báo.
enum StepSummary {
    static func action(_ action: StepAction) -> String {
        switch action {
        case let .click(button, count, hold):
            var text = "Click \(name(of: button))"
            if count > 1 { text += " ×\(count)" }
            if hold > 0 { text += ", giữ \(hold) ms" }
            return text
        case let .scroll(deltaX, deltaY):
            return "Cuộn (\(deltaX), \(deltaY))"
        case .move:
            return "Di chuột"
        case let .drag(button, destination):
            return "Kéo \(name(of: button)) tới \(target(destination))"
        case let .typeText(text):
            return text.isEmpty ? "Gõ chuỗi (trống)" : "Gõ “\(text)”"
        case let .pressKey(stroke):
            return "Phím \(KeyCatalog.describe(stroke))"
        }
    }

    static func target(_ target: StepTarget) -> String {
        switch target {
        case .cursor:
            return "Theo con trỏ"
        case let .screenPoint(x, y):
            return "Điểm màn hình X: \(Int(x.rounded()))  Y: \(Int(y.rounded()))"
        case let .windowRelative(corner, dx, dy):
            return "Lệch góc \(corner.title): \(Int(dx.rounded())), \(Int(dy.rounded()))"
        case let .template(name, settings):
            let label = name.isEmpty ? "chưa chụp" : name
            return "Ảnh mẫu \(label) (ngưỡng \(String(format: "%.2f", settings.threshold)))"
        case let .text(text, _):
            return text.isEmpty ? "Chữ (chưa nhập)" : "Chữ “\(text)”"
        }
    }

    static func name(of button: MouseButton) -> String {
        switch button {
        case .left: return "trái"
        case .right: return "phải"
        case .center: return "giữa"
        }
    }
}
