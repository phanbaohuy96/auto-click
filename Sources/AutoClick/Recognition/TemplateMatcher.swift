import CoreGraphics
import Foundation

/// Tìm **Ảnh mẫu** trong một ảnh lớn bằng tương quan chéo chuẩn hoá theo kim tự tháp (RG-8).
///
/// Apple không có API khớp mẫu — không có `matchTemplate`, MetalPerformanceShaders không có
/// tương quan chéo, Vision chỉ localize được chữ (RG-12). Đã tra SDK, đừng đi tìm lại.
///
/// Vì sao phải kim tự tháp: mẫu 120×48 trên màn hình 3024×1964 là khoảng 5,56 triệu vị trí ×
/// 5.760 điểm ảnh ≈ **32 tỉ phép so sánh** cho *một* lần giải Vị trí. Quét thô ở mức thu nhỏ rồi
/// tinh chỉnh quanh chỗ tốt nhất đưa con số đó xuống khoảng 9,5 triệu.
enum TemplateMatcher {
    struct Match: Equatable, Sendable {
        /// Góc trên-trái của vùng khớp, tính bằng điểm ảnh của ảnh lớn.
        var origin: CGPoint
        /// `0…1`; 1 là trùng khít.
        var score: Double
    }

    /// Bán kính tinh chỉnh quanh mỗi ứng viên thô, tính theo điểm ảnh ở độ phân giải gốc.
    static let refinementRadius = 8

    /// Số ứng viên thô được giữ lại để tinh chỉnh.
    ///
    /// Giữ đúng một ứng viên là không đủ: giao diện thật đầy hoạ tiết lặp (một hàng nút giống
    /// nhau, đường kẻ bảng), nên chỗ tốt nhất ở mức thô hay không phải chỗ đúng ở mức gốc.
    static let coarseCandidateLimit = 8

    /// Mức tương phản tối thiểu mà mẫu thu nhỏ phải giữ lại được so với mẫu gốc.
    ///
    /// Thu nhỏ quá tay sẽ **xoá sạch** hoạ tiết tần số cao — chữ, viền 1px, ô cờ nhỏ — biến mẫu
    /// thô thành một mảng gần như phẳng. Khi đó quét thô chỉ vào chỗ ngẫu nhiên và vùng tinh chỉnh
    /// còn không chứa vị trí đúng.
    static let contrastRetention: Float = 0.5

    /// Trần số phép so sánh cho một lần quét thô.
    ///
    /// Đây là ràng buộc đối nghịch với `contrastRetention`: giữ tương phản thì muốn thu nhỏ ít,
    /// còn quét thì muốn thu nhỏ nhiều. Không có trần này, một mẫu chi tiết trên màn hình đầy sẽ
    /// rơi về quét toàn phần — khoảng 32 tỉ phép so sánh, đúng thứ kim tự tháp sinh ra để tránh.
    static let coarseScanBudget = 40_000_000

    static func bestMatch(of template: GrayImage, in haystack: GrayImage) -> Match? {
        guard !template.isEmpty, !haystack.isEmpty,
              template.width <= haystack.width, template.height <= haystack.height else {
            return nil
        }

        let factor = downsampleFactor(for: template, in: haystack)
        guard factor > 1 else { return scan(template, in: haystack, region: nil) }

        let coarseTemplate = template.downsampled(by: factor)
        let coarseHaystack = haystack.downsampled(by: factor)
        guard coarseTemplate.width <= coarseHaystack.width,
              coarseTemplate.height <= coarseHaystack.height else {
            return scan(template, in: haystack, region: nil)
        }

        let candidates = topCandidates(
            coarseTemplate,
            in: coarseHaystack,
            limit: coarseCandidateLimit
        )
        guard !candidates.isEmpty else { return scan(template, in: haystack, region: nil) }

        let radius = refinementRadius + factor
        var best: Match?
        for candidate in candidates {
            let centerX = Int(candidate.origin.x) * factor
            let centerY = Int(candidate.origin.y) * factor
            let region = Region(
                minX: max(0, centerX - radius),
                minY: max(0, centerY - radius),
                maxX: min(haystack.width - template.width, centerX + radius),
                maxY: min(haystack.height - template.height, centerY + radius)
            )
            guard let refined = scan(template, in: haystack, region: region) else { continue }
            if refined.score > (best?.score ?? -.infinity) { best = refined }
        }
        return best
    }

    /// Mức thu nhỏ rẻ nhất vẫn giữ được tương phản của mẫu, trong giới hạn `coarseScanBudget`.
    ///
    /// Không chọn theo kích thước như trực giác ban đầu: một mẫu 32×32 vẫn có thể là ô cờ 3px,
    /// và thu nhỏ 8 lần sẽ trung bình hoá nó thành một mảng phẳng.
    ///
    /// RG-18: khi không mức nào vừa giữ được tương phản vừa nằm trong trần, trần thắng — thà khớp
    /// kém chính xác còn hơn treo giao diện nhiều giây cho một Bước. Thu hẹp **Vùng tìm** là cách
    /// người dùng lấy lại độ chính xác đó.
    static func downsampleFactor(for template: GrayImage, in haystack: GrayImage) -> Int {
        let fullContrast = standardDeviation(template.pixels)
        guard fullContrast > 0 else { return 1 }

        // Giảm dần: mức thu nhỏ lớn nhất là mức rẻ nhất.
        let usable = [8, 4, 2, 1].filter { factor in
            factor == 1
                || (template.width / factor >= 4 && template.height / factor >= 4)
        }
        let affordable = usable.filter { coarseScanCost(template, haystack, factor: $0) <= coarseScanBudget }

        let preserving = affordable.first { factor in
            factor == 1
                || standardDeviation(template.downsampled(by: factor).pixels)
                    >= fullContrast * contrastRetention
        }
        return preserving ?? affordable.first ?? usable.last ?? 1
    }

    private static func coarseScanCost(
        _ template: GrayImage,
        _ haystack: GrayImage,
        factor: Int
    ) -> Int {
        let positions = max(0, haystack.width / factor - template.width / factor + 1)
            * max(0, haystack.height / factor - template.height / factor + 1)
        let perPosition = max(1, (template.width / factor) * (template.height / factor))
        return positions * perPosition
    }

    /// Các đỉnh tương quan tách rời nhau ở mức thô.
    ///
    /// Triệt phi cực đại theo nửa kích thước mẫu, nếu không thì cả `limit` ứng viên sẽ nằm chồng
    /// lên nhau quanh đúng một đỉnh và việc giữ nhiều ứng viên trở thành vô nghĩa.
    private static func topCandidates(
        _ template: GrayImage,
        in haystack: GrayImage,
        limit: Int
    ) -> [Match] {
        let templateStatistics = statistics(of: template.pixels)
        guard templateStatistics.deviation > 0 else { return [] }

        let suppressionX = max(1, template.width / 2)
        let suppressionY = max(1, template.height / 2)
        var candidates: [Match] = []

        for originY in 0...(haystack.height - template.height) {
            for originX in 0...(haystack.width - template.width) {
                let score = correlation(
                    template: template,
                    templateStatistics: templateStatistics,
                    haystack: haystack,
                    originX: originX,
                    originY: originY
                )
                let match = Match(origin: CGPoint(x: originX, y: originY), score: score)

                if let index = candidates.firstIndex(where: {
                    abs(Int($0.origin.x) - originX) < suppressionX
                        && abs(Int($0.origin.y) - originY) < suppressionY
                }) {
                    if score > candidates[index].score { candidates[index] = match }
                    continue
                }

                candidates.append(match)
                candidates.sort { $0.score > $1.score }
                if candidates.count > limit { candidates.removeLast() }
            }
        }

        return candidates
    }

    private struct Region {
        var minX: Int
        var minY: Int
        var maxX: Int
        var maxY: Int
    }

    private static func scan(
        _ template: GrayImage,
        in haystack: GrayImage,
        region: Region?
    ) -> Match? {
        let templateStatistics = statistics(of: template.pixels)
        guard templateStatistics.deviation > 0 else {
            // Mẫu một màu phẳng không có gì để khớp; tương quan không xác định.
            return nil
        }

        let bounds = region ?? Region(
            minX: 0,
            minY: 0,
            maxX: haystack.width - template.width,
            maxY: haystack.height - template.height
        )
        guard bounds.maxX >= bounds.minX, bounds.maxY >= bounds.minY else { return nil }

        var best: Match?
        for originY in bounds.minY...bounds.maxY {
            for originX in bounds.minX...bounds.maxX {
                let score = correlation(
                    template: template,
                    templateStatistics: templateStatistics,
                    haystack: haystack,
                    originX: originX,
                    originY: originY
                )
                // RG-10: bằng điểm thì giữ chỗ tìm thấy trước — trên cùng, trái nhất — để kết quả
                // tất định giữa các lần chạy.
                if score > (best?.score ?? -.infinity) {
                    best = Match(origin: CGPoint(x: originX, y: originY), score: score)
                }
            }
        }
        return best
    }

    private struct Statistics {
        var mean: Double
        var deviation: Double
    }

    static func standardDeviation(_ pixels: [Float]) -> Float {
        Float(statistics(of: pixels).deviation / Double(max(1, pixels.count)).squareRoot())
    }

    private static func statistics(of pixels: [Float]) -> Statistics {
        let count = Double(pixels.count)
        let mean = pixels.reduce(0.0) { $0 + Double($1) } / count
        let variance = pixels.reduce(0.0) { $0 + (Double($1) - mean) * (Double($1) - mean) }
        return Statistics(mean: mean, deviation: variance.squareRoot())
    }

    /// Tương quan chéo chuẩn hoá tại một vị trí.
    ///
    /// Cộng dồn bằng `Double` chứ không `Float`, và đó **không** phải chuyện tinh chỉnh vi mô.
    /// Dạng `Σh² − n·h̄²` bị **triệt tiêu chữ số**: hai số lớn gần bằng nhau trừ nhau, phần chênh
    /// lệch nhỏ còn lại mất gần hết chữ số có nghĩa. Ở `Float` (23 bit định trị) với mẫu chừng
    /// 15.000 điểm ảnh, sai số lên tới ~2·10⁻³ — đủ để điểm vượt quá 1,0, vốn là điều không thể
    /// về mặt toán học.
    ///
    /// Vì sao quan trọng: hai nút gần giống nhau — chuyện thường ngày trong game — chênh nhau
    /// thật sự khoảng 4·10⁻⁵. Nhiễu Float lớn gấp 40 lần khoảng đó, nên bộ khớp **chọn bừa** giữa
    /// đúng và sai. Đo được khi chạy `I2` của kiểm thử tay: ảnh mẫu của ô A khớp vào ô B.
    private static func correlation(
        template: GrayImage,
        templateStatistics: Statistics,
        haystack: GrayImage,
        originX: Int,
        originY: Int
    ) -> Double {
        var windowTotal = 0.0
        var windowSquareTotal = 0.0
        var crossTotal = 0.0

        for y in 0..<template.height {
            let haystackRow = (originY + y) * haystack.width + originX
            let templateRow = y * template.width
            for x in 0..<template.width {
                let haystackValue = Double(haystack.pixels[haystackRow + x])
                windowTotal += haystackValue
                windowSquareTotal += haystackValue * haystackValue
                crossTotal += haystackValue * Double(template.pixels[templateRow + x])
            }
        }

        let count = Double(template.width * template.height)
        let windowMean = windowTotal / count
        let windowVariance = windowSquareTotal - count * windowMean * windowMean
        guard windowVariance > 0 else { return 0 }

        let numerator = crossTotal - count * windowMean * templateStatistics.mean
        let denominator = windowVariance.squareRoot() * templateStatistics.deviation
        guard denominator > 0 else { return 0 }

        return numerator / denominator
    }
}
