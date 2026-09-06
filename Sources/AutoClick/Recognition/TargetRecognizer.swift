import CoreGraphics
import Foundation

/// Đi tìm mục tiêu trên màn hình cho các **Vị trí** phải nhận dạng (DM-14, DM-15).
///
/// Là giao thức để bộ chạy kiểm chứng được ngữ nghĩa thử lại của `EX-8`/`EX-9` mà không cần chụp
/// màn hình thật.
@MainActor
protocol TargetRecognizing: AnyObject {
    /// Trỏ vào thư mục Ảnh mẫu của Kịch bản sắp chạy.
    func prepare(templatesDirectory: URL?)

    /// Toạ độ `CGEvent` của mục tiêu, hoặc `nil` nếu lần thử này chưa thấy.
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

        // RG-3: chụp lại ở mỗi lần thử. Mục đích của việc thử lại là thấy giao diện đã thay đổi.
        var best: (point: CGPoint, score: Double)?
        for captured in try await capture.capture(within: region) {
            guard let haystack = GrayImage(cgImage: captured.image),
                  let match = TemplateMatcher.bestMatch(of: template, in: haystack),
                  match.score >= settings.threshold else { continue }

            // RG-11: Vị trí trả về là tâm vùng khớp.
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

            // RG-15: tâm hộp bao của đoạn chữ khớp.
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
