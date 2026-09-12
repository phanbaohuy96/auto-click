import CoreGraphics
import Foundation

/// Goes looking on screen for the **Target**s that need recognition (DM-14, DM-15).
///
/// It is a protocol so the runner can verify the retry semantics of `EX-8`/`EX-9` without a real screen
/// capture.
@MainActor
protocol TargetRecognizing: AnyObject {
    /// Points at the Templates directory of the Scenario about to run.
    func prepare(templatesDirectory: URL?)

    /// The target's `CGEvent` coordinates, or `nil` if this attempt did not find it.
    func locate(_ target: StepTarget, within region: CGRect?) async throws -> CGPoint?
}

@MainActor
final class ScreenTargetRecognizer: TargetRecognizing {
    private let capture = ScreenCapture()
    private var templates: TemplateLibrary?

    func prepare(templatesDirectory: URL?) {
        templates = templatesDirectory.map(TemplateLibrary.init(directory:))
    }

    func locate(_ target: StepTarget, within region: CGRect?) async throws -> CGPoint? {
        switch target {
        case let .template(name, settings):
            return try await locateTemplate(name, settings: settings, within: region)
        case let .text(text, settings):
            return try await locateText(text, settings: settings, within: region)
        case .cursor, .screenPoint, .windowRelative:
            return nil
        }
    }

    private func locateTemplate(
        _ name: String,
        settings: RecognitionSettings,
        within region: CGRect?
    ) async throws -> CGPoint? {
        guard let template = templates?.loadGray(name) else { return nil }

        // RG-3: capture again on every attempt. The point of retrying is to see an interface that has changed.
        var best: (point: CGPoint, score: Double)?
        for captured in try await capture.capture(within: region) {
            guard let haystack = GrayImage(cgImage: captured.image),
                  let match = TemplateMatcher.bestMatch(of: template, in: haystack),
                  match.score >= settings.threshold else { continue }

            // RG-11: the Target returned is the centre of the matched area.
            let centre = CGPoint(
                x: match.origin.x + Double(template.width) / 2,
                y: match.origin.y + Double(template.height) / 2
            )
            let point = captured.screenPoint(fromPixel: centre)
            if match.score > (best?.score ?? -.infinity) {
                best = (point, match.score)
            }
        }
        return best?.point
    }

    private func locateText(
        _ text: String,
        settings: RecognitionSettings,
        within region: CGRect?
    ) async throws -> CGPoint? {
        var best: (point: CGPoint, confidence: Double)?
        for captured in try await capture.capture(within: region) {
            guard let match = TextFinder.find(text, in: captured.image) else { continue }

            // RG-15: the centre of the matched piece of text's bounding box.
            let point = captured.screenPoint(
                fromPixel: CGPoint(x: match.boundingBox.midX, y: match.boundingBox.midY)
            )
            if match.confidence > (best?.confidence ?? -.infinity) {
                best = (point, match.confidence)
            }
        }
        return best?.point
    }
}
