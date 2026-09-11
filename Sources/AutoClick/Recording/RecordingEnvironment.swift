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
    var anchorWindowFrame: (pid_t) -> CGRect?
    var application: (pid_t) -> LockedApplication?
    var doubleClickInterval: () -> TimeInterval
    /// Đồng hồ, tính bằng giây. Bơm được để test dựng khoảng nghỉ thật mà không phải chờ thật.
    var now: () -> TimeInterval

    static let live = RecordingEnvironment(
        ownProcessIdentifier: { ProcessInfo.processInfo.processIdentifier },
        frontmostProcessIdentifier: { NSWorkspace.shared.frontmostApplication?.processIdentifier },
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
