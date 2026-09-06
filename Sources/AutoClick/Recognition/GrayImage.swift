import CoreGraphics
import Foundation

/// Ảnh xám một kênh, dùng làm đầu vào cho việc khớp mẫu.
///
/// Kiểu riêng thay vì dùng thẳng `CGImage`: thuật toán khớp cần truy cập điểm ảnh hàng triệu lần
/// nên phải là mảng phẳng liên tục, và tách khỏi Core Graphics thì test dựng được ảnh bằng tay.
struct GrayImage: Equatable, Sendable {
    let width: Int
    let height: Int
    /// Độ sáng `0…1`, sắp theo hàng.
    var pixels: [Float]

    init(width: Int, height: Int, pixels: [Float]) {
        precondition(pixels.count == width * height, "Số điểm ảnh không khớp kích thước")
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    subscript(x: Int, y: Int) -> Float {
        pixels[y * width + x]
    }

    var isEmpty: Bool { width <= 0 || height <= 0 }

    /// Thu nhỏ bằng lấy trung bình từng ô `factor × factor`.
    func downsampled(by factor: Int) -> GrayImage {
        guard factor > 1 else { return self }
        let newWidth = width / factor
        let newHeight = height / factor
        guard newWidth > 0, newHeight > 0 else { return self }

        var result = [Float](repeating: 0, count: newWidth * newHeight)
        let divisor = Float(factor * factor)

        for y in 0..<newHeight {
            for x in 0..<newWidth {
                var total: Float = 0
                for offsetY in 0..<factor {
                    let row = (y * factor + offsetY) * width + x * factor
                    for offsetX in 0..<factor {
                        total += pixels[row + offsetX]
                    }
                }
                result[y * newWidth + x] = total / divisor
            }
        }

        return GrayImage(width: newWidth, height: newHeight, pixels: result)
    }

    /// Chuyển một `CGImage` bất kỳ về ảnh xám, không phụ thuộc không gian màu nguồn.
    init?(cgImage: CGImage) {
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return nil }

        var bytes = [UInt8](repeating: 0, count: width * height)
        guard let context = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        self.init(
            width: width,
            height: height,
            pixels: bytes.map { Float($0) / 255 }
        )
    }
}
