import Foundation

/// A horizontal run of pixels at a single y-coordinate, inclusive from `x1` to `x2`.
public struct Scanline: Equatable, Hashable, Sendable {
    public var y: Int
    public var x1: Int
    public var x2: Int

    @inlinable
    public init(y: Int, x1: Int, x2: Int) {
        self.y = y
        self.x1 = x1
        self.x2 = x2
    }

    /// Crops a set of scanlines so none extend past the given image bounds.
    public static func trim(_ scanlines: [Scanline], width: Int, height: Int) -> [Scanline] {
        var result: [Scanline] = []
        result.reserveCapacity(scanlines.count)
        for var line in scanlines {
            if line.y < 0 || line.y >= height || line.x1 >= width || line.x2 < 0 { continue }
            line.x1 = Util.clamp(line.x1, 0, width - 1)
            line.x2 = Util.clamp(line.x2, 0, width - 1)
            if line.x1 <= line.x2 {
                result.append(line)
            }
        }
        return result
    }
}
