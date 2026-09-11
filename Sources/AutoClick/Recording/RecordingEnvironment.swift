import AppKit
import CoreGraphics
import Foundation

/// Mọi thứ việc ghi cần hỏi hệ điều hành, gom vào một chỗ — cùng lối với `ScenarioSystemBridge`.
///
/// Tách ra vì phần bắt sự kiện chỉ chạy được khi có `CGEventTap` thật, mà tap thật lại đòi quyền
/// Accessibility và thao tác tay của người dùng. Với seam này, test bơm thẳng `CGEvent` dựng sẵn
/// vào `ScenarioRecorder.handle` và kiểm chứng được `RC-2`, `RC-12`, `RC-13` trên máy không quyền.
@MainActor
struct RecordingEnvironment {
    var ownProcessIdentifier: () -> pid_t
    var frontmostProcessIdentifier: () -> pid_t?
    /// Điểm này có rơi vào một cửa sổ của chính Auto Click không (`RC-2`).
    ///
    /// Không thể thay bằng `frontmostProcessIdentifier`: bảng nổi lúc ghi là `NSPanel` kiểu
    /// `.nonactivatingPanel`, bấm vào nó **không** làm Auto Click thành ứng dụng trước, nên hỏi
    /// "ai đang ở trước" vẫn ra ứng dụng kia và cú bấm "Kết thúc" lọt thẳng vào bản ghi.
    var pointIsInOwnWindow: (CGPoint) -> Bool
    var anchorWindowFrame: (pid_t) -> CGRect?
    var application: (pid_t) -> LockedApplication?
    var doubleClickInterval: () -> TimeInterval
    /// Đồng hồ, tính bằng giây. Bơm được để test dựng khoảng nghỉ thật mà không phải chờ thật.
    var now: () -> TimeInterval

    static let live = RecordingEnvironment(
        ownProcessIdentifier: { ProcessInfo.processInfo.processIdentifier },
        frontmostProcessIdentifier: { NSWorkspace.shared.frontmostApplication?.processIdentifier },
        pointIsInOwnWindow: { point in
            // `CGEvent.location` lấy gốc ở trên-trái màn hình chính, `NSWindow` lấy gốc dưới-trái.
            guard let mainScreen = NSScreen.screens.first else { return false }
            let flipped = NSPoint(x: point.x, y: mainScreen.frame.maxY - point.y)
            // Hỏi hệ thống cửa sổ nào **trên cùng** tại điểm đó, nên cửa sổ mình bị ứng dụng khác
            // che thì không tính là của mình.
            let number = NSWindow.windowNumber(at: flipped, belowWindowWithWindowNumber: 0)
            return NSApp.windows.contains { $0.isVisible && $0.windowNumber == number }
        },
        anchorWindowFrame: WindowAnchor.focusedWindowFrame(ofProcess:),
        application: { processIdentifier in
            guard let application = NSRunningApplication(processIdentifier: processIdentifier),
                  let bundleIdentifier = application.bundleIdentifier else { return nil }
            return LockedApplication(
                bundleIdentifier: bundleIdentifier,
                name: application.localizedName ?? bundleIdentifier
            )
        },
        doubleClickInterval: { NSEvent.doubleClickInterval },
        now: { Date().timeIntervalSinceReferenceDate }
    )
}
