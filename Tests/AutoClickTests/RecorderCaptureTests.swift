import CoreGraphics
import Foundation
import Testing
@testable import AutoClick

/// Phần bắt sự kiện của `ScenarioRecorder`: giải mã `CGEvent`, loại sự kiện của chính mình,
/// và lấy mẫu Cửa sổ neo đúng thời điểm.
///
/// Đây là đường mà trước đây chỉ `CGEventTap` thật mới chạy tới. Test bơm `CGEvent` dựng sẵn
/// thẳng vào `handle` nên chứng minh được `RC-2`, `RC-12`, `RC-13` trên máy không có quyền.
@MainActor
struct RecorderCaptureTests {
    private func makeRecorder(
        _ fake: FakeRecordingEnvironment
    ) -> (ScenarioRecorder, () -> RecordingAssembler.Result?) {
        let recorder = ScenarioRecorder(environment: fake.environment)
        var captured: RecordingAssembler.Result?
        recorder.onFinished = { captured = $0 }
        return (recorder, { captured })
    }

    private func click(
        _ recorder: ScenarioRecorder,
        _ fake: FakeRecordingEnvironment,
        at point: CGPoint,
        downAt downTime: TimeInterval,
        upAt upTime: TimeInterval
    ) {
        fake.now = downTime
        recorder.handle(type: .leftMouseDown, event: TestEvent.mouse(.leftMouseDown, at: point))
        fake.now = upTime
        recorder.handle(type: .leftMouseUp, event: TestEvent.mouse(.leftMouseUp, at: point))
    }

    /// RC-2: bấm nút "Kết thúc" trên bảng nổi lúc ghi không được thành một Bước.
    ///
    /// Bảng nổi là `NSPanel` kiểu `.nonactivatingPanel`: bấm vào nó **không** làm Auto Click
    /// thành ứng dụng trước, nên phép thử "ai đang ở trước" vẫn trả về ứng dụng đang được ghi và
    /// cú bấm lọt thẳng vào bản ghi. Chủ dự án gặp đúng vậy: ghi xong, bấm Kết thúc, bản ghi thừa
    /// một Bước click ngay chỗ cái nút.
    @Test func aClickOnTheFloatingPanelIsNotRecordedEvenThoughItDoesNotActivateTheApp() throws {
        let fake = FakeRecordingEnvironment()
        // Đúng như thật: ứng dụng trước vẫn là ứng dụng đang được ghi, không phải Auto Click.
        #expect(fake.frontmostProcessIdentifier == FakeRecordingEnvironment.otherProcessIdentifier)
        fake.ownWindowRects = [CGRect(x: 500, y: 40, width: 390, height: 86)]
        let (recorder, result) = makeRecorder(fake)

        // Một cú bấm thật vào ứng dụng đang được ghi…
        click(recorder, fake, at: CGPoint(x: 150, y: 140), downAt: 1_000, upAt: 1_000.05)
        // …rồi bấm "Kết thúc" trên bảng nổi.
        click(recorder, fake, at: CGPoint(x: 690, y: 83), downAt: 1_001, upAt: 1_001.05)
        recorder.finishSession()

        #expect(recorder.recordedGestureCount == 1)
        let scenario = try #require(result()?.scenario)
        #expect(scenario.steps.count == 1)
        #expect(scenario.steps[0].target == .windowRelative(corner: .topLeft, dx: 50, dy: 40))
    }

    /// RC-2: Auto Click đang là ứng dụng **ở trước** không làm mất cú bấm vào ứng dụng khác.
    ///
    /// Đúng luồng người dùng: mở popover, bấm "Ghi thao tác". Popover đóng nhưng Auto Click vẫn là
    /// ứng dụng ở trước, nên phép thử cũ ("ai đang ở trước") nuốt **thao tác đầu tiên của mọi bản
    /// ghi**, lặng lẽ. Đo trên app thật: ba cú bấm ra hai Bước, cú mất luôn là cú đầu.
    ///
    /// Và Ứng dụng khoá phải là ứng dụng **dưới con trỏ**, không phải Auto Click — nếu quy nhầm,
    /// cả phiên ghi bị coi là trải trên hai ứng dụng và mất luôn Vị trí tương đối cửa sổ.
    @Test func theFirstClickIsKeptEvenWhenAutoClickIsStillTheFrontmostApp() throws {
        let fake = FakeRecordingEnvironment()
        fake.frontmostProcessIdentifier = FakeRecordingEnvironment.ownProcessIdentifier
        fake.processIdentifierAtPoint = FakeRecordingEnvironment.otherProcessIdentifier
        let (recorder, result) = makeRecorder(fake)

        click(recorder, fake, at: CGPoint(x: 150, y: 140), downAt: 1_000, upAt: 1_000.05)
        // Cú thứ hai thì ứng dụng kia đã lên trước, như thật.
        fake.frontmostProcessIdentifier = FakeRecordingEnvironment.otherProcessIdentifier
        click(recorder, fake, at: CGPoint(x: 250, y: 140), downAt: 1_001, upAt: 1_001.05)
        recorder.finishSession()

        #expect(recorder.recordedGestureCount == 2)
        let outcome = try #require(result())
        #expect(outcome.scenario.steps.count == 2)
        #expect(outcome.scenario.lockedApplication?.bundleIdentifier == "com.test.Ghi")
        // Một ứng dụng duy nhất nên không có cảnh báo, và Vị trí được nâng lên tương đối cửa sổ.
        #expect(outcome.warning == nil)
        #expect(outcome.scenario.steps[0].target == .windowRelative(corner: .topLeft, dx: 50, dy: 40))
    }

    @Test func aPlainClickBecomesOneStepAnchoredToTheWindow() {
        let fake = FakeRecordingEnvironment()
        let (recorder, result) = makeRecorder(fake)

        click(recorder, fake, at: CGPoint(x: 150, y: 140), downAt: 1_000, upAt: 1_000.05)
        recorder.finishSession()

        let scenario = try! #require(result()?.scenario)
        #expect(scenario.steps.count == 1)
        #expect(scenario.steps[0].action == .click(button: .left, count: 1, holdMilliseconds: 0))
        // RC-13: có Ứng dụng khoá và có khung cửa sổ nên Vị trí được nâng lên tương đối.
        #expect(scenario.steps[0].target == .windowRelative(corner: .topLeft, dx: 50, dy: 40))
        #expect(scenario.lockedApplication?.bundleIdentifier == "com.test.Ghi")
        #expect(result()?.warning == nil)
    }

    @Test func eventsBelongingToAutoClickItselfAreNeverRecorded() {
        let fake = FakeRecordingEnvironment()
        // Điều kiện đúng là **điểm bấm rơi vào cửa sổ của mình**, không phải "mình đang ở trước".
        fake.ownWindowRects = [CGRect(x: 100, y: 100, width: 200, height: 120)]
        let (recorder, result) = makeRecorder(fake)

        click(recorder, fake, at: CGPoint(x: 150, y: 140), downAt: 1_000, upAt: 1_000.05)
        recorder.finishSession()

        // RC-2: bấm vào chính cửa sổ Auto Click không được lọt vào bản ghi.
        #expect(recorder.recordedGestureCount == 0)
        #expect(result() == nil)
        #expect(recorder.message == "Không ghi được thao tác nào.")
    }

    @Test func theScrollAxesAreNotSwapped() {
        let fake = FakeRecordingEnvironment()
        let (recorder, result) = makeRecorder(fake)

        recorder.handle(
            type: .scrollWheel,
            event: TestEvent.scroll(deltaX: 3, deltaY: -7, at: CGPoint(x: 200, y: 200))
        )
        recorder.finishSession()

        // Đảo hai trục là lỗi âm thầm: kịch bản vẫn chạy, chỉ cuộn sai chiều.
        let scenario = try! #require(result()?.scenario)
        #expect(scenario.steps[0].action == .scroll(deltaX: 3, deltaY: -7))
    }

    @Test func theAnchorWindowIsSampledAtGestureStartNotAtRelease() {
        let fake = FakeRecordingEnvironment()
        let (recorder, result) = makeRecorder(fake)

        fake.now = 1_000
        recorder.handle(
            type: .leftMouseDown,
            event: TestEvent.mouse(.leftMouseDown, at: CGPoint(x: 150, y: 140))
        )
        // Cửa sổ dịch chuyển giữa lúc giữ chuột; Vị trí phải tính theo khung lúc bắt đầu.
        fake.anchorWindowFrame = CGRect(x: 700, y: 700, width: 400, height: 300)
        fake.now = 1_000.05
        recorder.handle(
            type: .leftMouseUp,
            event: TestEvent.mouse(.leftMouseUp, at: CGPoint(x: 150, y: 140))
        )
        recorder.finishSession()

        let scenario = try! #require(result()?.scenario)
        #expect(scenario.steps[0].target == .windowRelative(corner: .topLeft, dx: 50, dy: 40))
    }

    @Test func aSessionSpanningTwoApplicationsFallsBackToAbsolutePointsAndSaysSo() {
        let fake = FakeRecordingEnvironment()
        fake.applications[7] = LockedApplication(bundleIdentifier: "com.test.Khac", name: "App Khác")
        let (recorder, result) = makeRecorder(fake)

        click(recorder, fake, at: CGPoint(x: 150, y: 140), downAt: 1_000, upAt: 1_000.05)
        fake.frontmostProcessIdentifier = 7
        click(recorder, fake, at: CGPoint(x: 160, y: 150), downAt: 1_002, upAt: 1_002.05)
        recorder.finishSession()

        // RC-14: không có Ứng dụng khoá nào đúng cho cả phiên nên phải nói ra, không im lặng.
        let unwrapped = try! #require(result())
        #expect(unwrapped.scenario.lockedApplication == nil)
        #expect(unwrapped.scenario.steps.allSatisfy { !$0.target.needsAnchorWindow })
        #expect(unwrapped.warning?.contains("2 ứng dụng") == true)
    }

    @Test func aDisabledTapIsReEnabledWithoutPollutingTheRecording() {
        let fake = FakeRecordingEnvironment()
        let (recorder, result) = makeRecorder(fake)

        recorder.handle(
            type: .tapDisabledByTimeout,
            event: TestEvent.mouse(.leftMouseDown, at: .zero)
        )
        click(recorder, fake, at: CGPoint(x: 150, y: 140), downAt: 1_000, upAt: 1_000.05)
        recorder.finishSession()

        // Sự kiện báo tap bị tắt không phải thao tác của người dùng.
        #expect(result()?.scenario.steps.count == 1)
    }

    @Test func theRealGapBetweenGesturesSurvivesIntoTheScenario() {
        let fake = FakeRecordingEnvironment()
        let (recorder, result) = makeRecorder(fake)

        click(recorder, fake, at: CGPoint(x: 150, y: 140), downAt: 1_000, upAt: 1_000.05)
        click(recorder, fake, at: CGPoint(x: 300, y: 250), downAt: 1_002.55, upAt: 1_002.6)
        recorder.finishSession()

        // ADR-0004: giữ nguyên 2,5 giây người dùng thật sự chờ, không cắt bớt.
        let steps = try! #require(result()?.scenario.steps)
        #expect(steps[0].delayMillisecondsAfter == 2_500)
        #expect(steps[1].delayMillisecondsAfter == 0)
    }
}

/// `SF-6` / ADR-0003: bộ ghi **không bao giờ** được nghe bàn phím.
///
/// Đây là ràng buộc an toàn mạnh nhất của dự án và trước đây không có test nào canh nó: mặt nạ sự
/// kiện nằm trong thân `startSession`, chỉ `CGEventTap` thật mới chạm tới. Ai đó thêm `.keyDown`
/// vào để "ghi cả phím cho tiện" sẽ biến Auto Click thành keylogger toàn hệ thống, kéo theo quyền
/// Input Monitoring, và mật khẩu gõ lúc đang ghi sẽ nằm nguyên văn trong `scenario.json`.
@MainActor
struct RecorderNeverListensToTheKeyboardTests {
    private func listens(to type: CGEventType) -> Bool {
        ScenarioRecorder.eventMask & (1 << type.rawValue) != 0
    }

    @Test func theEventMaskContainsNoKeyboardEvent() {
        #expect(!listens(to: .keyDown))
        #expect(!listens(to: .keyUp))
        #expect(!listens(to: .flagsChanged))

        // Và phải thật sự nghe chuột, nếu không khẳng định trên đúng một cách vô nghĩa.
        #expect(listens(to: .leftMouseDown))
        #expect(listens(to: .scrollWheel))
    }

    /// Vế thứ hai: kể cả khi mặt nạ bị nới ra, phần giải mã cũng không biến phím thành Bước.
    @Test func aKeyboardEventFedStraightIntoTheRecorderProducesNothing() {
        let fake = FakeRecordingEnvironment()
        let recorder = ScenarioRecorder(environment: fake.environment)
        var captured: RecordingAssembler.Result?
        recorder.onFinished = { captured = $0 }

        let key = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)!
        key.keyboardSetUnicodeString(stringLength: 6, unicodeString: Array("matkhau".utf16))
        recorder.handle(type: .keyDown, event: key)
        recorder.handle(type: .keyUp, event: CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)!)
        recorder.finishSession()

        #expect(recorder.recordedGestureCount == 0)
        #expect(captured == nil)
    }
}
