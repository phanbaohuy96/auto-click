import AppKit
import CoreGraphics
import Foundation

/// Chạy lớp phủ khoanh vùng rồi chụp vùng đó thành **Ảnh mẫu** (RG-4, RG-5).
@MainActor
final class TemplateCaptureCoordinator {
    /// Thời gian chờ cho window server thật sự gỡ lớp phủ khỏi màn hình trước khi chụp.
    ///
    /// RG-5: lớp phủ đang tô một lớp đen mờ lên toàn màn hình. Chụp lúc nó còn hiện sẽ cho ra
    /// Ảnh mẫu bị ám và không bao giờ khớp lại được lúc chạy. Ảnh chụp đã loại cửa sổ của chính
    /// Auto Click (RG-20), nhưng `orderOut` chỉ là yêu cầu — khoảng chờ này mới là thứ bảo đảm.
    static let overlayDismissDelayMilliseconds = 120

    private var selector: ScreenRegionSelector?

    /// Vùng tìm gợi ý quanh vùng vừa khoanh làm **Ảnh mẫu** (`RG-23`).
    ///
    /// Mặc định cũ là tìm cả màn hình, và đó là mặc định tệ cho ca dùng chính: trong game, thứ
    /// cần nhắm gần như luôn nằm lại đúng chỗ vừa chụp, còn quét cả màn hình vừa chậm hơn vừa dễ
    /// vớ phải một mảnh giống hệt ở nơi khác.
    ///
    /// Đệm lấy **nửa cạnh dài** của Ảnh mẫu — đủ cho mục tiêu xê dịch cỡ nửa chính nó — nhưng
    /// không dưới 48 point (ảnh mẫu bé xíu vẫn cần chỗ thở) và không quá 160 point (đệm to quá
    /// thì chẳng khác gì tìm cả màn hình).
    static func suggestedSearchRect(around rect: CGRect, within bounds: CGRect) -> CGRect {
        let padding = min(160, max(48, max(rect.width, rect.height) / 2))
        return rect.insetBy(dx: -padding, dy: -padding).intersection(bounds)
    }

    func selectRegion(prompt: String) async -> CGRect? {
        await withCheckedContinuation { continuation in
            let selector = ScreenRegionSelector()
            self.selector = selector
            selector.start(prompt: prompt) { rect in
                self.selector = nil
                NSApp.activate(ignoringOtherApps: true)
                continuation.resume(returning: rect)
            }
        }
    }

    /// Kết quả một lần chụp: tên tệp Ảnh mẫu, và **vùng đã khoanh** để suy ra Vùng tìm mặc định.
    struct Capture {
        let templateName: String
        let rect: CGRect
    }

    /// Khoanh một vùng, chụp nó, lưu vào kho và trả về tên tệp cùng vùng đã khoanh.
    func captureTemplate(into library: TemplateLibrary) async throws -> Capture? {
        guard let rect = await selectRegion(
            prompt: "Kéo để chọn vùng làm ảnh mẫu  •  Esc để hủy"
        ) else { return nil }

        try? await Task.sleep(for: .milliseconds(Self.overlayDismissDelayMilliseconds))

        let captured = try await ScreenCapture().capture(within: rect)
        guard let image = captured.first?.image else {
            throw ScreenCaptureError.permissionDenied
        }
        return Capture(templateName: try library.save(image), rect: rect)
    }
}
