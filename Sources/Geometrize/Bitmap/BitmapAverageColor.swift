import Foundation

extension Bitmap {
    /// Returns the average RGB color of all pixels, with the supplied alpha applied.
    public func averageColor(alpha: Int = 255) -> Rgba {
        var totalR = 0
        var totalG = 0
        var totalB = 0
        for p in pixels {
            totalR += p.r
            totalG += p.g
            totalB += p.b
        }
        let size = max(pixels.count, 1)
        return Rgba(r: totalR / size, g: totalG / size, b: totalB / size, a: alpha)
    }
}
