import AppKit
import CoreGraphics
import Foundation
import ScreenCaptureKit

/// Một mảnh màn hình đã chụp, kèm đủ thông tin để quy toạ độ điểm ảnh về toạ độ `CGEvent`.
struct CapturedImage: Sendable {
    var image: CGImage
    /// Vùng màn hình mà ảnh này phủ, tính bằng **point**, gốc trên-trái toàn cục.
    var frame: CGRect
    /// Số điểm ảnh trên mỗi point của màn hình chứa nó.
    var scale: Double

    /// Quy một điểm trong ảnh (đơn vị **pixel**) về toạ độ `CGEvent` (đơn vị **point**).
    ///
    /// RG-2: đây là nguồn bug kinh điển của tính năng này. Ảnh chụp ra pixel, `CGEvent` làm việc
    /// bằng point, và máy có màn hình retina lẫn màn hình ngoài sẽ có hai hệ số khác nhau trong
    /// cùng một không gian toạ độ.
    func screenPoint(fromPixel pixel: CGPoint) -> CGPoint {
        CGPoint(x: frame.minX + pixel.x / scale, y: frame.minY + pixel.y / scale)
    }
}

enum ScreenCaptureError: LocalizedError {
    case permissionDenied
    case noDisplays

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            // SF-7: nếu người dùng vừa bật quyền mà vẫn hỏng thì gần như chắc chắn là bản build
            // ký ad-hoc bị macOS coi là ứng dụng khác sau khi cập nhật. Cách sửa là khởi động
            // lại app, và câu này phải nói ra — hệ thống không phân biệt được hai trường hợp.
            return "Hãy cấp quyền Screen Recording cho Auto Click rồi thử lại. "
                + "Nếu đã cấp rồi, hãy thoát và mở lại Auto Click."
        case .noDisplays:
            return "Không tìm thấy màn hình nào để chụp."
        }
    }
}

/// Chụp màn hình bằng ScreenCaptureKit (RG-1, [ADR-0001]).
@MainActor
struct ScreenCapture {
    /// Chụp phần màn hình giao với `rect` (point, gốc trên-trái toàn cục); `nil` là chụp tất cả.
    ///
    /// Trả về một ảnh cho **mỗi màn hình** thay vì ghép lại: mỗi màn hình có hệ số scale riêng,
    /// ghép chung sẽ mất thông tin cần cho `RG-2`.
    func capture(within rect: CGRect? = nil) async throws -> [CapturedImage] {
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
        } catch {
            throw ScreenCaptureError.permissionDenied
        }

        guard !content.displays.isEmpty else { throw ScreenCaptureError.noDisplays }

        // RG-20: bỏ chính Auto Click ra khỏi ảnh chụp. Bảng nổi lúc chạy nằm ở giữa trên màn hình
        // và hoàn toàn có thể che mất mục tiêu cần tìm.
        let ownApplications = content.applications.filter {
            $0.processID == ProcessInfo.processInfo.processIdentifier
        }

        var results: [CapturedImage] = []
        for display in content.displays {
            let displayFrame = display.frame
            let region = rect.map { displayFrame.intersection($0) } ?? displayFrame
            guard !region.isNull, region.width >= 1, region.height >= 1 else { continue }

            let scale = self.scale(of: display)
            let configuration = SCStreamConfiguration()
            configuration.sourceRect = CGRect(
                x: region.minX - displayFrame.minX,
                y: region.minY - displayFrame.minY,
                width: region.width,
                height: region.height
            )
            configuration.width = Int((region.width * scale).rounded())
            configuration.height = Int((region.height * scale).rounded())
            configuration.captureResolution = .best
            configuration.showsCursor = false

            let filter = SCContentFilter(
                display: display,
                excludingApplications: ownApplications,
                exceptingWindows: []
            )

            guard let image = try? await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            ) else { continue }

            results.append(CapturedImage(image: image, frame: region, scale: scale))
        }

        guard !results.isEmpty else { throw ScreenCaptureError.permissionDenied }
        return results
    }

    private func scale(of display: SCDisplay) -> Double {
        let screen = NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
                == display.displayID
        }
        return screen.map { Double($0.backingScaleFactor) } ?? 2
    }
}
