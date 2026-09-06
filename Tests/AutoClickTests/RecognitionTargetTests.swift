import CoreGraphics
import Foundation
import Testing
@testable import AutoClick

private func templateStep(
    wait: Int,
    onTimeout: TimeoutBehaviour,
    region: SearchRegion? = nil,
    repeatCount: Int = 1
) -> Step {
    Step(
        action: .move,
        target: .template(
            name: "nut-ok.png",
            settings: RecognitionSettings(
                threshold: 0.9,
                searchRegion: region,
                waitMilliseconds: wait,
                onTimeout: onTimeout
            )
        ),
        repeatCount: repeatCount,
        delayMillisecondsAfter: 0
    )
}

@MainActor
@Test func aTemplateTargetMovesToWhereItWasFound() async {
    let recorder = EventRecorder()
    let recognizer = FakeRecognizer()
    recognizer.point = CGPoint(x: 640, y: 480)
    let runner = makeRunner(recorder: recorder, recognizer: recognizer)

    #expect(runner.start(Scenario(name: "Ảnh", steps: [templateStep(wait: 0, onTimeout: .stopScenario)])))
    #expect(await waitUntil { !runner.isRunning })

    #expect(recorder.records.map(\.location) == [CGPoint(x: 640, y: 480)])
}

/// EX-8: đây là chỗ "đợi nút Lưu hiện ra rồi bấm" được diễn đạt — bằng thời gian chờ, không phải
/// bằng vòng lặp có điều kiện.
@MainActor
@Test func aTemplateTargetRetriesUntilTheTargetAppears() async {
    let recorder = EventRecorder()
    let recognizer = FakeRecognizer()
    recognizer.foundOnAttempt = 3
    let runner = makeRunner(recorder: recorder, recognizer: recognizer)

    #expect(runner.start(Scenario(name: "Đợi", steps: [templateStep(wait: 5_000, onTimeout: .stopScenario)])))
    #expect(await waitUntil(timeout: .seconds(5)) { !runner.isRunning })

    #expect(recognizer.attempts == 3)
    #expect(recorder.records.count == 1)
}

@MainActor
@Test func aTemplateTargetTriesExactlyOnceWhenItIsNotAskedToWait() async {
    let recorder = EventRecorder()
    let recognizer = FakeRecognizer()
    recognizer.foundOnAttempt = nil
    let runner = makeRunner(recorder: recorder, recognizer: recognizer)

    #expect(runner.start(Scenario(name: "Không đợi", steps: [templateStep(wait: 0, onTimeout: .skipStep)])))
    #expect(await waitUntil { !runner.isRunning })

    #expect(recognizer.attempts == 1)
}

@MainActor
@Test func aMissingTemplateStopsTheScenarioWhenAskedTo() async {
    let recorder = EventRecorder()
    let recognizer = FakeRecognizer()
    recognizer.foundOnAttempt = nil
    let runner = makeRunner(recorder: recorder, recognizer: recognizer)

    let scenario = Scenario(
        name: "Dừng",
        steps: [
            templateStep(wait: 0, onTimeout: .stopScenario),
            Step(action: .move, target: .screenPoint(x: 1, y: 1), delayMillisecondsAfter: 0)
        ]
    )

    #expect(runner.start(scenario))
    #expect(await waitUntil { !runner.isRunning })

    #expect(recorder.records.isEmpty)
    #expect(runner.statusText.contains("nut-ok.png"))
}

/// EX-9: "bỏ qua bước" bỏ **toàn bộ** các lần lặp còn lại của Bước đó, không phải chỉ lần này.
@MainActor
@Test func skipOnTimeoutAbandonsEveryRemainingRepeatOfThatStep() async {
    let recorder = EventRecorder()
    let recognizer = FakeRecognizer()
    recognizer.foundOnAttempt = nil
    let runner = makeRunner(recorder: recorder, recognizer: recognizer)

    let scenario = Scenario(
        name: "Bỏ qua",
        steps: [
            templateStep(wait: 0, onTimeout: .skipStep, repeatCount: 5),
            Step(action: .move, target: .screenPoint(x: 9, y: 9), delayMillisecondsAfter: 0)
        ]
    )

    #expect(runner.start(scenario))
    #expect(await waitUntil { !runner.isRunning })

    // Thử đúng một lần rồi bỏ cả 5 lần lặp, nhưng Bước sau vẫn chạy.
    #expect(recognizer.attempts == 1)
    #expect(recorder.records.map(\.location) == [CGPoint(x: 9, y: 9)])
}

// MARK: - Vùng tìm

/// RG-7: không khoanh vùng thì thu hẹp về Cửa sổ neo khi có Ứng dụng khoá.
@MainActor
@Test func withoutASearchRegionTheAnchorWindowIsUsed() async {
    let recorder = EventRecorder()
    let recognizer = FakeRecognizer()
    let system = FakeSystem()
    system.anchorWindowFrame = CGRect(x: 100, y: 100, width: 800, height: 600)
    let runner = makeRunner(recorder: recorder, system: system, recognizer: recognizer)

    let scenario = Scenario(
        name: "Thu hẹp",
        steps: [templateStep(wait: 0, onTimeout: .stopScenario)],
        lockedApplication: FakeSystem.lockedApplication
    )

    #expect(runner.start(scenario))
    #expect(await waitUntil { !runner.isRunning })

    #expect(recognizer.regions == [CGRect(x: 100, y: 100, width: 800, height: 600)])
}

/// [ADR-0006]: Vị trí theo ảnh dùng được mà không cần Ứng dụng khoá — phạm vi khi đó là mọi màn hình.
@MainActor
@Test func aTemplateTargetWorksWithNoLockedApplication() async {
    let recorder = EventRecorder()
    let recognizer = FakeRecognizer()
    let runner = makeRunner(recorder: recorder, recognizer: recognizer)

    let scenario = Scenario(name: "Không khoá", steps: [templateStep(wait: 0, onTimeout: .stopScenario)])

    #expect(runner.validate(scenario) == nil)
    #expect(runner.start(scenario))
    #expect(await waitUntil { !runner.isRunning })

    #expect(recognizer.regions == [nil])
    #expect(recorder.records.count == 1)
}

@Test func aWindowRelativeSearchRegionResolvesAgainstTheAnchorWindow() {
    let resolver = TargetResolver(currentCursorPoint: { .zero })
    let frame = CGRect(x: 700, y: 300, width: 800, height: 600)

    let region = resolver.resolve(
        .windowRelative(corner: .topLeft, dx: 20, dy: 30, width: 400, height: 120),
        anchorWindowFrame: frame
    )

    #expect(region == CGRect(x: 720, y: 330, width: 400, height: 120))
}

/// [ADR-0006]: vùng tương đối cửa sổ mà không giải được thì lùi về phạm vi mặc định chứ không
/// báo lỗi — Vùng tìm không bao giờ ràng buộc Kịch bản phải có Ứng dụng khoá.
@Test func aWindowRelativeSearchRegionFallsBackInsteadOfFailing() {
    let resolver = TargetResolver(currentCursorPoint: { .zero })

    let region = resolver.resolve(
        .windowRelative(corner: .topLeft, dx: 20, dy: 30, width: 400, height: 120),
        anchorWindowFrame: nil
    )

    #expect(region == nil)
}

// MARK: - Lưu trữ

@Test func recognitionTargetsSurviveARoundTrip() throws {
    let scenario = Scenario(
        name: "Nhận dạng",
        steps: [
            Step(
                action: .click(button: .left, count: 1, holdMilliseconds: 0),
                target: .template(
                    name: "nut-ok.png",
                    settings: RecognitionSettings(
                        threshold: 0.85,
                        searchRegion: .windowRelative(
                            corner: .bottomRight, dx: -300, dy: -120, width: 280, height: 100
                        ),
                        waitMilliseconds: 10_000,
                        onTimeout: .skipStep
                    )
                )
            ),
            Step(
                action: .move,
                target: .text(
                    "Đồng ý",
                    settings: RecognitionSettings(
                        searchRegion: .screenRect(x: 10, y: 20, width: 300, height: 200)
                    )
                )
            )
        ]
    )

    let data = try JSONEncoder().encode(scenario)
    #expect(try JSONDecoder().decode(Scenario.self, from: data) == scenario)
}

@Test func aTemplateTargetNamesTheFileItNeeds() {
    let scenario = Scenario(
        name: "t",
        steps: [
            Step(action: .move, target: .template(name: "a.png", settings: RecognitionSettings())),
            Step(
                action: .drag(
                    button: .left,
                    destination: .template(name: "b.png", settings: RecognitionSettings())
                ),
                target: .cursor
            )
        ]
    )

    #expect(scenario.templateNames == ["a.png", "b.png"])
}
