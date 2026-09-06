import CoreGraphics
import Foundation
import Vision

/// Tìm một đoạn chữ trên ảnh bằng Vision OCR (RG-13…RG-16).
///
/// Khác hẳn khớp **Ảnh mẫu** về độ bền: đổi giao diện sáng/tối, đổi cỡ chữ hệ thống, hay cắm màn
/// hình khác độ phân giải đều làm ảnh mẫu trượt nhưng không ảnh hưởng tới việc đọc chữ. Đổi lại,
/// nó chỉ nhắm được thứ **có chữ** — icon, ô vuông, phần tử game thì chịu.
enum TextFinder {
    struct Match: Equatable, Sendable {
        /// Hộp bao của đoạn chữ, tính bằng điểm ảnh của ảnh đầu vào, gốc trên-trái.
        var boundingBox: CGRect
        var confidence: Double
    }

    static func find(_ needle: String, in image: CGImage) -> Match? {
        let target = normalise(needle)
        guard !target.isEmpty else { return nil }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = recognitionLanguages

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        guard (try? handler.perform([request])) != nil,
              let observations = request.results else { return nil }

        let width = Double(image.width)
        let height = Double(image.height)
        var best: Match?

        for observation in observations {
            guard let candidate = observation.topCandidates(1).first,
                  normalise(candidate.string).contains(target) else { continue }

            // Vision trả về toạ độ chuẩn hoá với gốc ở **dưới-trái**; ảnh và `CGEvent` dùng
            // gốc **trên-trái**, nên phải lật trục dọc.
            let box = observation.boundingBox
            let match = Match(
                boundingBox: CGRect(
                    x: box.minX * width,
                    y: (1 - box.maxY) * height,
                    width: box.width * width,
                    height: box.height * height
                ),
                confidence: Double(candidate.confidence)
            )

            // RG-16: điểm cao nhất thắng; bằng nhau thì giữ đoạn tìm thấy trước (RG-10).
            if match.confidence > (best?.confidence ?? -.infinity) {
                best = match
            }
        }

        return best
    }

    /// RG-14: không phân biệt hoa thường, bỏ khoảng trắng thừa hai đầu.
    static func normalise(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static var recognitionLanguages: [String] {
        var languages = Locale.preferredLanguages
        if !languages.contains(where: { $0.hasPrefix("en") }) {
            languages.append("en-US")
        }
        return languages
    }
}
