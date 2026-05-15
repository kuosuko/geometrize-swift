import Foundation

/// An RGBA8888 bitmap stored as a flat row-major array of pixels.
///
/// `Bitmap` is a class (reference type) so the algorithm can mutate the current and buffer
/// images in place without paying the cost of a value-type copy on every pixel write.
public final class Bitmap {
    public let width: Int
    public let height: Int

    /// Row-major pixel storage. Length is `width * height`.
    @usableFromInline
    var pixels: [Rgba]

    private init(width: Int, height: Int, pixels: [Rgba]) {
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    /// Creates a new bitmap filled with the given background color.
    public static func create(width: Int, height: Int, color: Rgba) -> Bitmap {
        precondition(width >= 0 && height >= 0)
        return Bitmap(
            width: width,
            height: height,
            pixels: Array(repeating: color, count: width * height)
        )
    }

    /// Creates a bitmap from a flat array of bytes laid out as RGBA8888. Length must be `width * height * 4`.
    public static func create(width: Int, height: Int, bytes: [UInt8]) -> Bitmap {
        precondition(bytes.count == width * height * 4, "Byte array must be width * height * 4 long")
        let pixelCount = width * height
        let pixels = [Rgba](unsafeUninitializedCapacity: pixelCount) { buf, count in
            bytes.withUnsafeBufferPointer { src in
                let s = src.baseAddress!
                for i in 0..<pixelCount {
                    let o = i * 4
                    let r = UInt32(s[o])
                    let g = UInt32(s[o + 1])
                    let b = UInt32(s[o + 2])
                    let a = UInt32(s[o + 3])
                    buf[i] = Rgba(value: (r << 24) | (g << 16) | (b << 8) | a)
                }
            }
            count = pixelCount
        }
        return Bitmap(width: width, height: height, pixels: pixels)
    }

    @inlinable
    public func getPixel(x: Int, y: Int) -> Rgba {
        pixels[width * y + x]
    }

    @inlinable
    public func setPixel(x: Int, y: Int, color: Rgba) {
        pixels[width * y + x] = color
    }

    /// Hot-path accessor — gives the caller direct buffer access for one closure.
    /// The buffer is row-major, length `width * height`, mutable in place.
    @inlinable
    func withUnsafeMutablePixels<R>(_ body: (inout UnsafeMutableBufferPointer<Rgba>) -> R) -> R {
        pixels.withUnsafeMutableBufferPointer(body)
    }

    @inlinable
    func withUnsafePixels<R>(_ body: (UnsafeBufferPointer<Rgba>) -> R) -> R {
        pixels.withUnsafeBufferPointer(body)
    }

    /// Returns a deep copy.
    public func clone() -> Bitmap {
        Bitmap(width: width, height: height, pixels: pixels)
    }

    /// Fills the bitmap with the given color.
    public func fill(_ color: Rgba) {
        for i in 0..<pixels.count {
            pixels[i] = color
        }
    }

    /// Returns the raw bytes laid out as RGBA8888.
    public func getBytes() -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: pixels.count * 4)
        for i in 0..<pixels.count {
            let p = pixels[i]
            let o = i * 4
            bytes[o]     = UInt8(p.r)
            bytes[o + 1] = UInt8(p.g)
            bytes[o + 2] = UInt8(p.b)
            bytes[o + 3] = UInt8(p.a)
        }
        return bytes
    }
}
