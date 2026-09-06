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
    var processIdentifier: (_ bundleIdentifier: String) -> pid_t?
    var isRunning: (pid_t) -> Bool
    var activate: (pid_t) -> Void
    var frontmostProcessIdentifier: () -> pid_t?
    var anchorWindowFrame: (pid_t) -> CGRect?
    var processIdentifierAtPoint: (CGPoint) -> pid_t?

    static let live = ScenarioSystemBridge(
        isAccessibilityTrusted: ScenarioSystemBridge.requestAccessibilityAccess,
        processIdentifier: { bundleIdentifier in
            guard !bundleIdentifier.isEmpty else { return nil }
            return NSWorkspace.shared.runningApplications.first {
                $0.bundleIdentifier == bundleIdentifier && !$0.isTerminated
            }?.processIdentifier
        },
        isRunning: { NSRunningApplication(processIdentifier: $0) != nil },
        activate: { processIdentifier in
            NSRunningApplication(processIdentifier: processIdentifier)?
                .activate(options: [.activateAllWindows])
        },
        frontmostProcessIdentifier: { NSWorkspace.shared.frontmostApplication?.processIdentifier },
        anchorWindowFrame: WindowAnchor.focusedWindowFrame(ofProcess:),
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
