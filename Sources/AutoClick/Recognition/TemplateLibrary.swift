import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import os

/// Kho **Ảnh mẫu** của một Kịch bản: các tệp PNG trong `templates/` của chính thư mục Kịch bản.
///
/// Ảnh mẫu được nhân bản chứ không dùng chung giữa các Kịch bản — xem [ADR-0005].
@MainActor
final class TemplateLibrary {
    private static let logger = Logger(subsystem: "com.local.AutoClick", category: "Templates")

    private let directory: URL
    /// Ảnh đã giải mã, giữ lại giữa các lần thử lại của `EX-8`. Không cache thì mỗi 150 ms lại
    /// đọc và giải mã PNG một lần.
    private var cache: [String: GrayImage] = [:]

    init(directory: URL) {
        self.directory = directory
    }

    func url(for name: String) -> URL {
        directory.appendingPathComponent(name)
    }

    /// Lưu một mảnh ảnh vừa cắt và trả về tên tệp của nó.
    func save(_ image: CGImage) throws -> String {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = "\(UUID().uuidString.prefix(8)).png"
        let target = url(for: name)

        guard let destination = CGImageDestinationCreateWithURL(
            target as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return name
    }

    func loadGray(_ name: String) -> GrayImage? {
        if let cached = cache[name] { return cached }

        guard let source = CGImageSourceCreateWithURL(url(for: name) as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let gray = GrayImage(cgImage: image) else {
            Self.logger.error("Không đọc được ảnh mẫu \(name, privacy: .public)")
            return nil
        }
        cache[name] = gray
        return gray
    }

    func loadImage(_ name: String) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url(for: name) as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    /// Xoá các tệp không còn Bước nào dùng tới, để thư mục Kịch bản không phình theo mỗi lần
    /// người dùng đổi ảnh mẫu.
    func removeUnused(keeping names: Set<String>) {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []

        for file in files where !names.contains(file.lastPathComponent) {
            try? FileManager.default.removeItem(at: file)
            cache[file.lastPathComponent] = nil
        }
    }
}
