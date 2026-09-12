import CoreGraphics
import Foundation
import Testing
@testable import AutoClick

/// Bản ghi phải chỉ ra được **cửa sổ**, không chỉ ứng dụng.
///
/// Phát hiện lúc chuẩn bị `D10` của kiểm thử tay: máy đang mở hai tiến trình Chrome — Chrome
/// thường ngày của người dùng và phiên Chrome cách ly của bộ đo. Hai tiến trình cùng
/// `bundleIdentifier`, nên `runningApplications.first` trả về tiến trình của người dùng và bản
/// ghi dựng trên cửa sổ nháp sẽ chạy lại lên cửa sổ đang đăng nhập. Cùng một lỗ hổng còn ở mức
/// nhẹ hơn với **một** tiến trình nhiều cửa sổ: cửa sổ nào đang focus lúc chạy thì trúng cửa sổ ấy.
@MainActor
@Suite struct AnchorWindowIdentityTests {
    /// Bộ ghi phải nhớ tiêu đề cửa sổ, nếu không thì lúc chạy chẳng có gì để chọn đúng.
    @Test func aRecordingRemembersWhichWindowItWasMadeOn() {
        let environment = FakeRecordingEnvironment()
        environment.anchorWindowTitle = "Bản nháp — chưa lưu"
        var finished: RecordingAssembler.Result?
        let recorder = ScenarioRecorder(environment: environment.environment)
        recorder.onFinished = { finished = $0 }

        let point = CGPoint(x: 150, y: 150)
        recorder.handle(type: .leftMouseDown, event: TestEvent.mouse(.leftMouseDown, at: point))
        environment.now += 0.05
        recorder.handle(type: .leftMouseUp, event: TestEvent.mouse(.leftMouseUp, at: point))
        recorder.finishSession()

        #expect(finished?.scenario.lockedApplication?.windowTitle == "Bản nháp — chưa lưu")
    }

    /// Giữa hai tiến trình cùng bundle id, phải chọn cái đang mở đúng cửa sổ đã ghi.
    @Test func theProcessOwningTheRecordedWindowWinsOverTheFirstOneListed() async {
        let events = EventRecorder()
        let system = FakeSystem()
        let intruder: pid_t = 1          // khởi động trước, nên đứng đầu danh sách
        let recorded: pid_t = 2
        system.runningApplications = [FakeSystem.applicationBundleIdentifier: recorded]
        system.windowTitles = [intruder: ["Hộp thư — đã đăng nhập"], recorded: ["Bản nháp"]]
        system.frameForWindowTitle = ["Bản nháp": CGRect(x: 500, y: 400, width: 300, height: 200)]
        // SF-3 đòi cú bấm phải rơi vào chính ứng dụng đã khoá, nên bia dưới con trỏ cũng là nó.
        system.processIdentifierAtPoint = recorded

        let runner = makeRunner(recorder: events, system: system)
        var locked = FakeSystem.lockedApplication
        locked.windowTitle = "Bản nháp"

        let scenario = Scenario(
            name: "Neo theo cửa sổ",
            steps: [
                Step(
                    action: .move,
                    target: .windowRelative(corner: .topLeft, dx: 10, dy: 20),
                    delayMillisecondsAfter: 0
                )
            ],
            lockedApplication: locked
        )

        #expect(runner.start(scenario))
        #expect(await waitUntil { !runner.isRunning })

        // Khung phải lấy từ cửa sổ đã ghi, không phải từ cửa sổ đang focus.
        #expect(events.records.first?.location == CGPoint(x: 510, y: 420))
        #expect(system.anchorLookups.contains { $0.title == "Bản nháp" })
    }

    /// Bản ghi cũ không có tiêu đề thì vẫn chạy y như trước, không được từ chối.
    @Test func aRecordingWithoutAWindowTitleStillResolvesTheOldWay() async {
        let events = EventRecorder()
        let system = FakeSystem()
        system.anchorWindowFrame = CGRect(x: 700, y: 300, width: 800, height: 600)
        let runner = makeRunner(recorder: events, system: system)

        let scenario = Scenario(
            name: "Bản ghi cũ",
            steps: [
                Step(
                    action: .move,
                    target: .windowRelative(corner: .topLeft, dx: 120, dy: 88),
                    delayMillisecondsAfter: 0
                )
            ],
            lockedApplication: FakeSystem.lockedApplication   // windowTitle = nil
        )

        #expect(runner.start(scenario))
        #expect(await waitUntil { !runner.isRunning })
        #expect(events.records.first?.location == CGPoint(x: 820, y: 388))
        #expect(system.anchorLookups.allSatisfy { $0.title == nil })
    }

    /// Tiêu đề chỉ là **ưu tiên**: cửa sổ đã đổi tên thì vẫn phải chạy, không được đứng im.
    @Test func aTitleThatNoLongerMatchesFallsBackInsteadOfRefusingToRun() async {
        let events = EventRecorder()
        let system = FakeSystem()
        system.anchorWindowFrame = CGRect(x: 700, y: 300, width: 800, height: 600)
        system.windowTitles = [FakeSystem.applicationProcessIdentifier: ["Tên mới hoàn toàn"]]
        let runner = makeRunner(recorder: events, system: system)

        var locked = FakeSystem.lockedApplication
        locked.windowTitle = "Tên lúc ghi"

        let scenario = Scenario(
            name: "Tiêu đề đã đổi",
            steps: [
                Step(
                    action: .move,
                    target: .windowRelative(corner: .topLeft, dx: 120, dy: 88),
                    delayMillisecondsAfter: 0
                )
            ],
            lockedApplication: locked
        )

        #expect(runner.start(scenario))
        #expect(await waitUntil { !runner.isRunning })
        #expect(events.records.first?.location == CGPoint(x: 820, y: 388))
    }

    /// Tiêu đề phải đi qua được vòng mã hoá, nếu không thì lưu xong là mất.
    @Test func theWindowTitleSurvivesASaveAndLoad() throws {
        var locked = FakeSystem.lockedApplication
        locked.windowTitle = "Bản nháp — chưa lưu"
        let scenario = Scenario(name: "Vòng tròn", steps: [], lockedApplication: locked)

        let data = try JSONEncoder().encode(scenario)
        let decoded = try JSONDecoder().decode(Scenario.self, from: data)

        #expect(decoded.lockedApplication?.windowTitle == "Bản nháp — chưa lưu")
    }

    /// Tệp cũ **không có** khoá `windowTitle` vẫn phải đọc được (ST-10).
    @Test func aScenarioFileFromBeforeThisFieldStillLoads() throws {
        let json = """
        {
          "schemaVersion": 1,
          "id": "11111111-1111-4111-8111-111111111111",
          "name": "Bản cũ",
          "repeat": 1,
          "steps": [],
          "lockedApplication": { "bundleIdentifier": "com.test.App", "name": "App Thử" }
        }
        """
        let decoded = try JSONDecoder().decode(Scenario.self, from: Data(json.utf8))
        #expect(decoded.lockedApplication?.bundleIdentifier == "com.test.App")
        #expect(decoded.lockedApplication?.windowTitle == nil)
    }
}
