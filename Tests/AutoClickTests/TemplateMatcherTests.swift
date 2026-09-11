import CoreGraphics
import Foundation
import Testing
@testable import AutoClick

/// Dựng ảnh nền nhiễu tất định rồi dán một hoạ tiết vào đúng một chỗ.
private func haystack(
    width: Int,
    height: Int,
    patch: GrayImage,
    at origin: (x: Int, y: Int)
) -> GrayImage {
    var pixels = [Float](repeating: 0, count: width * height)
    for index in pixels.indices {
        // Nhiễu tất định, không dùng random, để test không bao giờ chập chờn.
        pixels[index] = Float((index * 37) % 100) / 400
    }
    for y in 0..<patch.height {
        for x in 0..<patch.width {
            pixels[(origin.y + y) * width + origin.x + x] = patch[x, y]
        }
    }
    return GrayImage(width: width, height: height, pixels: pixels)
}

private func checkerboard(width: Int, height: Int) -> GrayImage {
    var pixels = [Float](repeating: 0, count: width * height)
    for y in 0..<height {
        for x in 0..<width {
            pixels[y * width + x] = (x / 3 + y / 3) % 2 == 0 ? 0.95 : 0.05
        }
    }
    return GrayImage(width: width, height: height, pixels: pixels)
}

@Test func aTemplateIsFoundAtItsExactLocation() throws {
    let patch = checkerboard(width: 24, height: 18)
    let image = haystack(width: 300, height: 200, patch: patch, at: (x: 137, y: 88))

    let match = try #require(TemplateMatcher.bestMatch(of: patch, in: image))

    #expect(match.origin == CGPoint(x: 137, y: 88))
    #expect(match.score > 0.99)
}

/// RG-8: đường kim tự tháp phải cho cùng kết quả với quét thẳng, nếu không thì tối ưu hoá đã
/// âm thầm đổi hành vi.
@Test func theCoarseToFinePathAgreesWithAnExhaustiveScan() throws {
    let patch = checkerboard(width: 32, height: 32)
    let image = haystack(width: 400, height: 300, patch: patch, at: (x: 201, y: 154))

    #expect(TemplateMatcher.downsampleFactor(for: patch, in: image) > 1)
    let match = try #require(TemplateMatcher.bestMatch(of: patch, in: image))

    #expect(match.origin == CGPoint(x: 201, y: 154))
}

/// Mẫu nhỏ không được thu nhỏ đến mức teo thành vài điểm ảnh vô nghĩa.
@Test func aTinyTemplateIsNotDownsampledAway() {
    let tiny = checkerboard(width: 6, height: 6)
    let image = checkerboard(width: 200, height: 200)

    #expect(TemplateMatcher.downsampleFactor(for: tiny, in: image) == 1)
}

/// Ràng buộc đối nghịch: mẫu chi tiết trên ảnh lớn vẫn phải nằm trong trần chi phí, kể cả khi
/// điều đó có nghĩa là mất tương phản (RG-18). Không có trần này thì một Bước sẽ treo hàng giây.
@Test func aFineGrainedTemplateOnALargeImageStaysWithinTheScanBudget() {
    let patch = checkerboard(width: 120, height: 48)
    let screen = checkerboard(width: 3024, height: 1964)

    let factor = TemplateMatcher.downsampleFactor(for: patch, in: screen)

    #expect(factor > 1)
    let positions = (3024 / factor - 120 / factor + 1) * (1964 / factor - 48 / factor + 1)
    let cost = positions * (120 / factor) * (48 / factor)
    #expect(cost <= TemplateMatcher.coarseScanBudget)
}

@Test func aTemplateLargerThanTheImageHasNoMatch() {
    let patch = checkerboard(width: 40, height: 40)
    let image = checkerboard(width: 20, height: 20)

    #expect(TemplateMatcher.bestMatch(of: patch, in: image) == nil)
}

/// Mẫu một màu phẳng không có gì để khớp — tương quan chuẩn hoá không xác định ở đó.
/// Trả về `nil` thay vì một con số bịa ra.
@Test func aFlatTemplateHasNoMatch() {
    let flat = GrayImage(width: 10, height: 10, pixels: [Float](repeating: 0.5, count: 100))
    let image = checkerboard(width: 100, height: 100)

    #expect(TemplateMatcher.bestMatch(of: flat, in: image) == nil)
}

/// Ảnh không chứa mẫu vẫn trả về vị trí tốt nhất, nhưng điểm phải thấp hơn hẳn ngưỡng mặc định
/// — đó là cách bên gọi phân biệt "thấy" với "không thấy".
@Test func anAbsentTemplateScoresWellBelowTheDefaultThreshold() throws {
    let patch = checkerboard(width: 24, height: 24)
    var pixels = [Float](repeating: 0, count: 300 * 200)
    for index in pixels.indices {
        pixels[index] = Float((index * 37) % 100) / 400
    }
    let image = GrayImage(width: 300, height: 200, pixels: pixels)

    let match = try #require(TemplateMatcher.bestMatch(of: patch, in: image))

    #expect(match.score < 0.9)
}

/// Khớp mẫu dựa vào tương quan nên không đổi khi cả vùng sáng lên hay tối đi đều — đúng thứ ta
/// cần khi độ sáng màn hình thay đổi.
@Test func matchingSurvivesAUniformBrightnessShift() throws {
    let patch = checkerboard(width: 20, height: 20)
    var brighter = patch
    brighter.pixels = patch.pixels.map { min(1, $0 * 0.6 + 0.3) }
    let image = haystack(width: 200, height: 160, patch: brighter, at: (x: 90, y: 60))

    let match = try #require(TemplateMatcher.bestMatch(of: patch, in: image))

    #expect(match.origin == CGPoint(x: 90, y: 60))
    #expect(match.score > 0.99)
}

@Test func downsamplingAveragesEachBlock() {
    let image = GrayImage(width: 4, height: 2, pixels: [0, 1, 0, 1, 1, 0, 1, 0])

    let smaller = image.downsampled(by: 2)

    #expect(smaller.width == 2)
    #expect(smaller.height == 1)
    #expect(smaller.pixels == [0.5, 0.5])
}

// MARK: - Độ chính xác số học

/// Một hoạ tiết tất định, **sáng và tương phản thấp**.
///
/// Đây chính là điều kiện làm `Σh² − n·h̄²` mất hết chữ số có nghĩa: hai số lớn gần bằng nhau
/// trừ nhau. Giao diện thật đầy chỗ như vậy — nút sáng màu, nền phẳng, icon nhạt.
private func speckle(width: Int, height: Int, seed: UInt64 = 12_345,
                     base: Float = 0.90, spread: Float = 0.02) -> [Float] {
    var state = seed
    return (0..<(width * height)).map { _ in
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return base + Float((state >> 33) % 1000) / 1000 * spread
    }
}

/// Tương quan chuẩn hoá **không thể** vượt quá 1: đó là định nghĩa của nó.
///
/// Điểm lớn hơn 1 là dấu hiệu triệt tiêu chữ số trong `Σh² − n·h̄²`. Cộng dồn bằng `Float` cho
/// mẫu cỡ 15.000 điểm ảnh sinh sai số tới ~2·10⁻³ và test này đỏ.
@Test func anExactMatchNeverScoresAboveOne() throws {
    // Đúng cỡ mẫu của ca thật (một icon 62pt trên màn hình retina). Sai số Float tăng theo số
    // điểm ảnh, nên mẫu nhỏ không tái hiện được lỗi. Khung ảnh giữ chật để quét vẫn nhanh.
    let side = 124
    let template = GrayImage(width: side, height: side, pixels: speckle(width: side, height: side))

    var canvas = [Float](repeating: 0.91, count: 260 * 130)
    for y in 0..<side {
        for x in 0..<side {
            canvas[(3 + y) * 260 + 40 + x] = template.pixels[y * side + x]
        }
    }
    let image = GrayImage(width: 260, height: 130, pixels: canvas)

    let match = try #require(TemplateMatcher.bestMatch(of: template, in: image))
    #expect(match.origin == CGPoint(x: 40, y: 3))
    // Nới đúng bằng sai số dấu phẩy động không tránh được (~10⁻¹³), không hơn. Cộng dồn bằng
    // `Float` cho ra 1,0017 và test này đỏ.
    #expect(match.score <= 1.000_000_1)
    #expect(match.score > 0.999_99)
}

/// Hai mục tiêu gần giống nhau — chuyện thường ngày trong game — phải chọn đúng cái khớp thật.
///
/// Chênh lệch thật giữa hai vùng ở đây khoảng 10⁻⁴. Cộng dồn bằng `Float` sinh nhiễu lớn hơn thế
/// một bậc, nên bộ khớp chọn bừa; đo trên máy thật thì nó chọn nhầm.
@Test func aNearIdenticalNeighbourDoesNotStealTheMatch() throws {
    let side = 124
    let pattern = speckle(width: side, height: side)
    let template = GrayImage(width: side, height: side, pixels: pattern)

    // Bản sao gần giống: lệch rất nhỏ và **không đều**, nên không phải phép biến đổi tuyến tính
    // mà tương quan chuẩn hoá vốn bỏ qua.
    var neighbour = pattern
    for i in stride(from: 0, to: neighbour.count, by: 37) {
        neighbour[i] = min(1, neighbour[i] + 0.0008)
    }

    var canvas = [Float](repeating: 0.91, count: 300 * 130)
    for y in 0..<side {
        for x in 0..<side {
            canvas[(3 + y) * 300 + 10 + x] = pattern[y * side + x]         // bản khớp thật
            canvas[(3 + y) * 300 + 160 + x] = neighbour[y * side + x]      // bản gần giống
        }
    }
    let image = GrayImage(width: 300, height: 130, pixels: canvas)

    let match = try #require(TemplateMatcher.bestMatch(of: template, in: image))
    #expect(match.origin == CGPoint(x: 10, y: 3))
}
