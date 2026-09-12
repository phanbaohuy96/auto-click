import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

/// Mọi thứ bộ chạy cần hỏi hệ điều hành, gom vào một chỗ.
///
/// Tách ra để test kiểm chứng được `SF-4` (đưa Ứng dụng khoá lên trước khi gõ phím) và `EX-7`
/// (thiếu Cửa sổ neo thì dừng) mà không phải mở ứng dụng thật.
@MainActor
struct ScenarioSystemBridge {
    var isAccessibilityTrusted: () -> Bool
    /// Tiến trình để nhắm tới. `preferredWindowTitle` là tiêu đề **Cửa sổ neo** lúc ghi: hai tiến
    /// trình cùng bundle id (hai hồ sơ trình duyệt, hai bản game) thì phải có nó mới chọn đúng.
    var processIdentifier: (_ bundleIdentifier: String, _ preferredWindowTitle: String?) -> pid_t?
    var isRunning: (pid_t) -> Bool
    var activate: (pid_t) -> Void
    var frontmostProcessIdentifier: () -> pid_t?
    var anchorWindowFrame: (_ processIdentifier: pid_t, _ preferredWindowTitle: String?) -> CGRect?
    var processIdentifierAtPoint: (CGPoint) -> pid_t?

    static let live = ScenarioSystemBridge(
        isAccessibilityTrusted: ScenarioSystemBridge.requestAccessibilityAccess,
        processIdentifier: { bundleIdentifier, preferredWindowTitle in
            guard !bundleIdentifier.isEmpty else { return nil }
            let candidates = NSWorkspace.shared.runningApplications
                .filter { $0.bundleIdentifier == bundleIdentifier && !$0.isTerminated }
                .map(\.processIdentifier)
            // Có tiêu đề thì chọn tiến trình thật sự đang mở cửa sổ ấy. Không có, hoặc không tiến
            // trình nào khớp, thì giữ nguyên nết cũ — lấy cái đầu tiên.
            if let title = preferredWindowTitle, !title.isEmpty,
               let owner = candidates.first(where: {
                   WindowAnchor.hasWindow(ofProcess: $0, titled: title)
               }) {
                return owner
            }
            return candidates.first
        },
        isRunning: { NSRunningApplication(processIdentifier: $0) != nil },
        activate: { processIdentifier in
            NSRunningApplication(processIdentifier: processIdentifier)?
                .activate(options: [.activateAllWindows])
        },
        frontmostProcessIdentifier: { NSWorkspace.shared.frontmostApplication?.processIdentifier },
        anchorWindowFrame: WindowAnchor.frame(ofProcess:preferringTitle:),
        processIdentifierAtPoint: ScenarioSystemBridge.processIdentifier(at:)
    )

    private nonisolated static func requestAccessibilityAccess() -> Bool {
        if AXIsProcessTrusted() { return true }

        // The SDK exposes kAXTrustedCheckOptionPrompt as mutable global state, which Swift 6
        // rejects under strict concurrency checking. This is its documented CFString value.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private nonisolated static func processIdentifier(at point: CGPoint) -> pid_t? {
        let systemWideElement = AXUIElementCreateSystemWide()
        var element: AXUIElement?
        let copyResult = AXUIElementCopyElementAtPosition(
            systemWideElement,
            Float(point.x),
            Float(point.y),
            &element
        )
        guard copyResult == .success, let element else { return nil }

        var processIdentifier: pid_t = 0
        guard AXUIElementGetPid(element, &processIdentifier) == .success else { return nil }
        return processIdentifier
    }
}
