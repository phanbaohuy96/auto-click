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

    /// Khoanh một vùng, chụp nó, lưu vào kho và trả về tên tệp.
    func captureTemplate(into library: TemplateLibrary) async throws -> String? {
        guard let rect = await selectRegion(
            prompt: "Kéo để chọn vùng làm ảnh mẫu  •  Esc để hủy"
        ) else { return nil }

        try? await Task.sleep(for: .milliseconds(Self.overlayDismissDelayMilliseconds))

        let captured = try await ScreenCapture().capture(within: rect)
        guard let image = captured.first?.image else {
            throw ScreenCaptureError.permissionDenied
        }
        return try library.save(image)
    }
}
