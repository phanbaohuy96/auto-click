import Foundation
import Testing
@testable import AutoClick

@MainActor
private struct Fixture {
    let root: URL
    let defaults: UserDefaults

    init() {
        root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("AutoClickTests-\(UUID().uuidString)", isDirectory: true)
        defaults = UserDefaults(suiteName: "AutoClickTests-\(UUID().uuidString)")!
    }

    func makeStore() -> ScenarioStore {
        ScenarioStore(rootDirectory: root, defaults: defaults)
    }

    func write(_ json: String, into folder: String) throws {
        let directory = root.appendingPathComponent(folder, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(json.utf8).write(to: directory.appendingPathComponent("scenario.json"))
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: root)
    }
}

@MainActor
@Test func savedScenariosComeBackOnReload() throws {
    let fixture = Fixture()
    defer { fixture.cleanUp() }

    let store = fixture.makeStore()
    var scenario = store.create(name: "Xoá hàng loạt")
    scenario.steps = [Step(action: .move, target: .screenPoint(x: 3, y: 4))]
    scenario.runCount = .untilStopped
    store.save(scenario)

    let reopened = fixture.makeStore()

    #expect(reopened.scenarios.count == 1)
    #expect(reopened.scenarios[0].name == "Xoá hàng loạt")
    #expect(reopened.scenarios[0].runCount == .untilStopped)
    #expect(reopened.scenarios[0].steps.count == 1)
    // ST-4: lựa chọn đang hoạt động sống trong UserDefaults, không phải trong file kịch bản.
    #expect(reopened.selectedScenarioID == scenario.id)
}

/// ST-3: xoá Kịch bản là xoá cả thư mục, kể cả những gì nằm trong nó.
@MainActor
@Test func deletingAScenarioRemovesItsWholeFolder() throws {
    let fixture = Fixture()
    defer { fixture.cleanUp() }

    let store = fixture.makeStore()
    let scenario = store.create(name: "Tạm")
    let folder = fixture.root.appendingPathComponent(scenario.id.uuidString)
    let template = folder.appendingPathComponent("templates", isDirectory: true)
    try FileManager.default.createDirectory(at: template, withIntermediateDirectories: true)

    store.delete(scenario)

    #expect(!FileManager.default.fileExists(atPath: folder.path))
    #expect(store.scenarios.isEmpty)
}

@MainActor
@Test func duplicatingGivesFreshIdentifiersToEveryStep() throws {
    let fixture = Fixture()
    defer { fixture.cleanUp() }

    let store = fixture.makeStore()
    var original = store.create(name: "Gốc")
    original.steps = [
        Step(action: .move, target: .cursor),
        Step(action: .click(button: .left, count: 1, holdMilliseconds: 0), target: .cursor)
    ]
    store.save(original)

    let copy = try #require(store.duplicate(original))

    #expect(copy.id != original.id)
    #expect(copy.name == "Gốc (bản sao)")
    #expect(Set(copy.steps.map(\.id)).isDisjoint(with: Set(original.steps.map(\.id))))
    #expect(copy.steps.map(\.action) == original.steps.map(\.action))
}

/// ST-9: một thư mục hỏng không được làm mất các Kịch bản còn lại.
@MainActor
@Test func aCorruptFolderDoesNotHideTheHealthyOnes() throws {
    let fixture = Fixture()
    defer { fixture.cleanUp() }

    try fixture.write("{ not json at all", into: "broken")
    try fixture.write(
        """
        { "schemaVersion": 1, "id": "\(UUID().uuidString)", "name": "Lành lặn", "repeat": 1, "steps": [] }
        """,
        into: "healthy"
    )

    let store = fixture.makeStore()

    #expect(store.scenarios.map(\.name) == ["Lành lặn"])
    #expect(store.loadIssues.count == 1)
}

/// ST-12: định dạng mới hơn thì nạp tên để hiển thị, nhưng không sửa và không ghi đè.
@MainActor
@Test func aNewerSchemaLoadsReadOnlyInsteadOfBeingMisread() throws {
    let fixture = Fixture()
    defer { fixture.cleanUp() }

    let id = UUID()
    try fixture.write(
        """
        { "schemaVersion": 99, "id": "\(id.uuidString)", "name": "Từ tương lai", "steps": [] }
        """,
        into: id.uuidString
    )

    let store = fixture.makeStore()
    let scenario = try #require(store.scenarios.first)

    #expect(scenario.name == "Từ tương lai")
    #expect(store.isReadOnly(scenario))

    var edited = scenario
    edited.name = "Đã sửa"
    store.save(edited)

    #expect(fixture.makeStore().scenarios.first?.name == "Từ tương lai")
}

/// ST-12: nhân bản một Kịch bản chỉ đọc phải **không làm gì**, chứ không đẻ ra một bản rỗng.
///
/// Bản nạp của Kịch bản chỉ đọc chỉ có `id` và `name` — các Bước nằm trong phần JSON app này
/// không giải mã được. Nhân bản nó từng ghi ra đĩa một Kịch bản mang tên bản gốc, `schemaVersion`
/// hiện tại và **không Bước nào**, trông y như thật. Người dùng tưởng đã cứu được dữ liệu rồi xoá
/// bản gốc là mất sạch. Tìm ra ở `E2` của kiểm thử tay.
@MainActor
@Test func aReadOnlyScenarioCannotBeDuplicatedIntoAnEmptyOne() throws {
    let fixture = Fixture()
    defer { fixture.cleanUp() }

    let id = UUID()
    try fixture.write(
        """
        { "schemaVersion": 99, "id": "\(id.uuidString)", "name": "Từ tương lai", "steps": [] }
        """,
        into: id.uuidString
    )

    let store = fixture.makeStore()
    let scenario = try #require(store.scenarios.first)

    #expect(store.duplicate(scenario) == nil)
    #expect(store.scenarios.count == 1)
    // Và không có thư mục thứ hai nào xuất hiện trên đĩa.
    let folders = try FileManager.default.contentsOfDirectory(atPath: fixture.root.path)
    #expect(folders == [id.uuidString])
}
