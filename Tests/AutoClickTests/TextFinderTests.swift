import AppKit
import CoreText
import Testing
@testable import AutoClick

/// Vẽ một dòng chữ đen trên nền trắng để có ảnh thật cho Vision đọc.
///
/// Đây là một trong số ít chỗ dùng phụ thuộc thật thay vì bộ giả: cái cần kiểm là **Vision trả
/// về hộp bao của đoạn nào**, nên thay Vision bằng đồ giả là kiểm mất đúng thứ cần kiểm.
private func imageOfText(_ text: String, width: Int = 1000, height: Int = 180) -> CGImage {
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))

    let font = CTFontCreateWithName("Helvetica" as CFString, 72, nil)
    let attributed = NSAttributedString(
        string: text,
        attributes: [
            .font: font,
            .foregroundColor: CGColor(red: 0, green: 0, blue: 0, alpha: 1)
        ]
    )
    context.textPosition = CGPoint(x: 40, y: 60)
    CTLineDraw(CTLineCreateWithAttributedString(attributed), context)
    return context.makeImage()!
}

/// RG-15: Vị trí trả về phải là tâm **đoạn chữ khớp**, không phải tâm cả dòng.
///
/// Vision gộp cả dòng thành một observation. Lấy `observation.boundingBox` thì tìm `"Lưu"` trong
/// dòng `"Lưu   ⌘S"` sẽ click vào khoảng trống giữa dòng. Phát hiện khi chạy `C9` của kiểm thử
/// tay: click rơi đúng tâm cả dòng, lệch 83 point khỏi từ cần nhắm.
@Test func twoWordsOnOneLineGiveTwoDifferentBoxes() throws {
    let image = imageOfText("ZUKAMI QWERTY")

    let first = try #require(TextFinder.find("ZUKAMI", in: image))
    let second = try #require(TextFinder.find("QWERTY", in: image))

    // Nếu lấy hộp của cả dòng thì hai hộp này **bằng nhau** và khẳng định dưới đây sập.
    #expect(first.boundingBox.midX < second.boundingBox.midX)
    #expect(second.boundingBox.minX > first.boundingBox.maxX - 1)

    // Mỗi hộp phải hẹp hơn hẳn cả dòng, chứ không phải trùm cả hai từ.
    let lineWidth = second.boundingBox.maxX - first.boundingBox.minX
    #expect(first.boundingBox.width < lineWidth * 0.7)
    #expect(second.boundingBox.width < lineWidth * 0.7)
}

/// RG-14: không phân biệt hoa thường.
@Test func caseDoesNotChangeWhatIsFound() throws {
    let image = imageOfText("ZUKAMI QWERTY")

    let upper = try #require(TextFinder.find("ZUKAMI", in: image))
    let lower = try #require(TextFinder.find("zukami", in: image))

    #expect(abs(upper.boundingBox.midX - lower.boundingBox.midX) < 2)
    #expect(abs(upper.boundingBox.midY - lower.boundingBox.midY) < 2)
}

@Test func textThatIsNotOnTheImageIsNotFound() {
    #expect(TextFinder.find("KHONGCOCHUNAY", in: imageOfText("ZUKAMI QWERTY")) == nil)
}
