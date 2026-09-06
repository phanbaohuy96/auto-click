import AppKit
import CoreGraphics

/// Quyền Screen Recording, tách biệt hoàn toàn với Accessibility (SF-5, SF-7).
///
/// App giờ cần hai quyền khác nhau và người dùng rất dễ cấp một rồi quên cái kia, nên trạng thái
/// này phải hiển thị được chứ không chỉ nằm trong một thông báo lỗi lúc chạy.
@MainActor
enum ScreenRecordingPermission {
    static var isGranted: Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Bật hộp thoại xin quyền của hệ thống. Chỉ gọi khi người dùng thật sự dùng tới tính năng
    /// nhận dạng — không xin lúc khởi động (SF-5).
    @discardableResult
    static func request() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    static func openSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        ) else { return }
        NSWorkspace.shared.open(url)
    }
}
