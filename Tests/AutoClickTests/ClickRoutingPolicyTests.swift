import CoreGraphics
import Foundation
import Testing
@testable import AutoClick

/// Cổng gác của **Ứng dụng khoá** cho sự kiện có toạ độ (EX-10).
///
/// Hai mươi dòng này là thứ duy nhất chặn một Kịch bản bắn vào cửa sổ lạ khi người dùng
/// vô tình kéo cửa sổ khác lên trên, nên nó phải sai theo hướng an toàn.
struct ClickRoutingPolicyTests {
    private let target: pid_t = 1234

    @Test func withoutALockedApplicationEveryPointIsAllowed() {
        // Chế độ đơn giản không khoá ứng dụng: không có gì để so, không được chặn.
        #expect(ClickRoutingPolicy.route(
            targetProcessIdentifier: nil,
            processIdentifierAtPoint: 999
        ) == .systemEventTap)
        #expect(ClickRoutingPolicy.route(
            targetProcessIdentifier: nil,
            processIdentifierAtPoint: nil
        ) == .systemEventTap)
    }

    @Test func aPointInsideTheLockedApplicationIsAllowed() {
        #expect(ClickRoutingPolicy.route(
            targetProcessIdentifier: target,
            processIdentifierAtPoint: target
        ) == .systemEventTap)
    }

    @Test func aPointOverAnotherApplicationIsBlocked() {
        #expect(ClickRoutingPolicy.route(
            targetProcessIdentifier: target,
            processIdentifierAtPoint: 5678
        ) == nil)
    }

    @Test func anUnidentifiablePointIsBlockedRatherThanAssumedSafe() {
        // Hỏi được là ai thì mới bắn. Không biết dưới con trỏ là gì mà vẫn click là cách
        // để Kịch bản bấm vào thứ người dùng không ngờ tới.
        #expect(ClickRoutingPolicy.route(
            targetProcessIdentifier: target,
            processIdentifierAtPoint: nil
        ) == nil)
    }
}
