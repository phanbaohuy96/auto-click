import CoreGraphics
import Foundation
import Testing
@testable import AutoClick

/// Kho **Ảnh mẫu**: ghi đĩa thật vào thư mục tạm. Đây là I/O nên hỏng được thật —
/// mã hoá PNG, chuyển sang ảnh xám, và dọn tệp thừa (ST-12, RG-19).
@MainActor
struct TemplateLibraryTests {
    private func makeDirectory() -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("AutoClickTemplates-\(UUID().uuidString)")
        return directory
    }

    /// Ảnh ô cờ: giá trị điểm ảnh khác nhau rõ rệt nên vòng PNG có sai lệch là thấy ngay.
    private func makeImage(width: Int, height: Int) -> CGImage {
        var bytes = [UInt8](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                bytes[y * width + x] = (x / 2 + y / 2) % 2 == 0 ? 20 : 230
            }
        }
        let context = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        )!
        return context.makeImage()!
    }

    @Test func savingThenLoadingReturnsTheSamePixels() throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let library = TemplateLibrary(directory: directory)
        let image = makeImage(width: 8, height: 6)

        // Thư mục chưa tồn tại: `save` phải tự tạo chứ không ném lỗi.
        let name = try library.save(image)
        let loaded = try #require(library.loadGray(name))

        #expect(loaded.width == 8)
        #expect(loaded.height == 6)
        let original = try #require(GrayImage(cgImage: image))
        // PNG không mất dữ liệu; chênh lệch chỉ có thể đến từ chuyển đổi không gian màu.
        for index in original.pixels.indices {
            #expect(abs(loaded.pixels[index] - original.pixels[index]) < 0.02)
        }
    }

    @Test func aMissingTemplateReturnsNilInsteadOfCrashing() {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let library = TemplateLibrary(directory: directory)

        // Kịch bản chép tay thiếu tệp là chuyện thật; bộ chạy phải báo không thấy chứ không sập.
        #expect(library.loadGray("khong-ton-tai.png") == nil)
        #expect(library.loadImage("khong-ton-tai.png") == nil)
    }

    @Test func cleaningUpRemovesOnlyTheTemplatesNoStepUsesAnyMore() throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let library = TemplateLibrary(directory: directory)

        let kept = try library.save(makeImage(width: 8, height: 6))
        let dropped = try library.save(makeImage(width: 8, height: 6))

        library.removeUnused(keeping: [kept])

        #expect(FileManager.default.fileExists(atPath: library.url(for: kept).path))
        #expect(!FileManager.default.fileExists(atPath: library.url(for: dropped).path))
    }

    @Test func aRemovedTemplateIsNotStillServedFromTheCache() throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let library = TemplateLibrary(directory: directory)

        let name = try library.save(makeImage(width: 8, height: 6))
        #expect(library.loadGray(name) != nil)  // nạp vào cache

        library.removeUnused(keeping: [])

        // Không xoá cache thì bộ chạy vẫn khớp theo ảnh đã bị xoá — sai lặng lẽ, khó lần ra.
        #expect(library.loadGray(name) == nil)
    }
}
