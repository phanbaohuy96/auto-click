import Foundation
import SwiftUI
import os

/// Kho Kịch bản trên đĩa: mỗi Kịch bản một thư mục (ADR-0005, ST-1…ST-3).
///
/// Không có bộ đếm tham chiếu ở đâu cả — xoá Kịch bản là xoá cả thư mục, kể cả Ảnh mẫu bên
/// trong nó. Hai Kịch bản dùng chung một nút sẽ giữ hai bản sao của cùng một Ảnh mẫu, cố ý.
@MainActor
final class ScenarioStore: ObservableObject {
    @Published private(set) var scenarios: [Scenario] = []
    /// Kịch bản thuộc định dạng mới hơn: nạp được tên nhưng không sửa và không chạy (ST-12).
    @Published private(set) var readOnlyScenarioIDs: Set<UUID> = []
    @Published private(set) var loadIssues: [String] = []

    @Published var selectedScenarioID: UUID? {
        didSet {
            defaults.set(selectedScenarioID?.uuidString, forKey: Self.selectedKey)
        }
    }

    private static let selectedKey = "selectedScenarioID"
    private static let logger = Logger(subsystem: "com.local.AutoClick", category: "ScenarioStore")

    private let defaults: UserDefaults
    private let fileManager: FileManager
    private let rootDirectory: URL

    init(defaults: UserDefaults = .standard, fileManager: FileManager = .default) {
        self.defaults = defaults
        self.fileManager = fileManager
        self.rootDirectory = Self.defaultRootDirectory(using: fileManager)
        self.selectedScenarioID = defaults.string(forKey: Self.selectedKey).flatMap(UUID.init)
        reload()
    }

    /// Chỉ dùng trong test: trỏ kho vào một thư mục tạm.
    init(rootDirectory: URL, defaults: UserDefaults, fileManager: FileManager = .default) {
        self.defaults = defaults
        self.fileManager = fileManager
        self.rootDirectory = rootDirectory
        self.selectedScenarioID = defaults.string(forKey: Self.selectedKey).flatMap(UUID.init)
        reload()
    }

    var selectedScenario: Scenario? {
        guard let selectedScenarioID else { return nil }
        return scenarios.first { $0.id == selectedScenarioID }
    }

    func isReadOnly(_ scenario: Scenario) -> Bool {
        readOnlyScenarioIDs.contains(scenario.id)
    }

    /// Binding ghi thẳng xuống đĩa: trình soạn thảo không có nút Lưu (UI-11).
    func binding(for id: UUID) -> Binding<Scenario> {
        Binding(
            get: { self.scenarios.first { $0.id == id } ?? Scenario(id: id, name: "") },
            set: { self.save($0) }
        )
    }

    // MARK: - Đọc

    func reload() {
        var loaded: [Scenario] = []
        var readOnly: Set<UUID> = []
        var issues: [String] = []

        let directories = (try? fileManager.contentsOfDirectory(
            at: rootDirectory,
            includingPropertiesForKeys: [.isDirectoryKey]
        )) ?? []

        for directory in directories {
            let file = directory.appendingPathComponent("scenario.json")
            guard let data = try? Data(contentsOf: file) else { continue }

            do {
                loaded.append(try JSONDecoder().decode(Scenario.self, from: data))
            } catch {
                // Một thư mục hỏng không được làm mất các Kịch bản còn lại (ST-9).
                if let header = try? JSONDecoder().decode(ScenarioHeader.self, from: data),
                   header.schemaVersion > ScenarioSchema.currentVersion {
                    loaded.append(Scenario(id: header.id, name: header.name))
                    readOnly.insert(header.id)
                    issues.append("\(header.name): định dạng phiên bản \(header.schemaVersion), chỉ xem được.")
                } else {
                    Self.logger.error(
                        "Bỏ qua \(file.path, privacy: .public): \(error.localizedDescription, privacy: .public)"
                    )
                    issues.append("\(directory.lastPathComponent): không đọc được scenario.json.")
                }
            }
        }

        scenarios = loaded.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        readOnlyScenarioIDs = readOnly
        loadIssues = issues

        if let selectedScenarioID, !scenarios.contains(where: { $0.id == selectedScenarioID }) {
            self.selectedScenarioID = scenarios.first?.id
        } else if selectedScenarioID == nil {
            selectedScenarioID = scenarios.first?.id
        }
    }

    // MARK: - Ghi

    @discardableResult
    func create(name: String = "Kịch bản mới") -> Scenario {
        let scenario = Scenario(name: uniqueName(from: name))
        save(scenario)
        selectedScenarioID = scenario.id
        return scenario
    }

    func save(_ scenario: Scenario) {
        guard !readOnlyScenarioIDs.contains(scenario.id) else { return }

        let directory = rootDirectory.appendingPathComponent(scenario.id.uuidString)
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes, .sortedKeys]
            let data = try encoder.encode(scenario)
            // Ghi nguyên tử để tắt máy giữa chừng không để lại scenario.json cụt (ST-11).
            try data.write(to: directory.appendingPathComponent("scenario.json"), options: .atomic)
        } catch {
            Self.logger.error("Không lưu được kịch bản: \(error.localizedDescription, privacy: .public)")
            return
        }

        if let index = scenarios.firstIndex(where: { $0.id == scenario.id }) {
            // Không sắp xếp lại ở đây: đổi tên được lưu theo từng ký tự gõ, và sắp xếp lại mỗi
            // lần sẽ làm dòng đang sửa nhảy khỏi chỗ. Thứ tự được chuẩn hoá lại ở `reload()`.
            scenarios[index] = scenario
        } else {
            scenarios.append(scenario)
            scenarios.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    @discardableResult
    func duplicate(_ scenario: Scenario) -> Scenario {
        var copy = scenario
        copy.id = UUID()
        copy.name = uniqueName(from: "\(scenario.name) (bản sao)")
        copy.steps = scenario.steps.map { step in
            var duplicated = step
            duplicated.id = UUID()
            return duplicated
        }
        save(copy)
        selectedScenarioID = copy.id
        return copy
    }

    func delete(_ scenario: Scenario) {
        let directory = rootDirectory.appendingPathComponent(scenario.id.uuidString)
        try? fileManager.removeItem(at: directory)
        scenarios.removeAll { $0.id == scenario.id }
        readOnlyScenarioIDs.remove(scenario.id)
        if selectedScenarioID == scenario.id {
            selectedScenarioID = scenarios.first?.id
        }
    }

    private func uniqueName(from name: String) -> String {
        let existing = Set(scenarios.map(\.name))
        guard existing.contains(name) else { return name }
        var index = 2
        while existing.contains("\(name) \(index)") { index += 1 }
        return "\(name) \(index)"
    }

    private static func defaultRootDirectory(using fileManager: FileManager) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base
            .appendingPathComponent("AutoClick", isDirectory: true)
            .appendingPathComponent("Scenarios", isDirectory: true)
    }
}
