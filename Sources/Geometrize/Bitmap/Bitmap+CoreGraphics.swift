#if canImport(CoreGraphics)
import Foundation
import CoreGraphics

extension Bitmap {
    /// Decodes a `CGImage` into a `Bitmap`. The image is redrawn into an RGBA8 context so the result
    /// is always in the format the algorithm expects, regardless of the source color space.
    public static func from(cgImage: CGImage, maxDimension: Int? = nil) -> Bitmap? {
        let srcWidth = cgImage.width
        let srcHeight = cgImage.height

        var width = srcWidth
        var height = srcHeight
        if let cap = maxDimension, max(width, height) > cap {
            let scale = Double(cap) / Double(max(width, height))
            width = max(1, Int((Double(srcWidth) * scale).rounded()))
            height = max(1, Int((Double(srcHeight) * scale).rounded()))
        }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var raw = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

        let ctx = raw.withUnsafeMutableBytes { ptr -> CGContext? in
            guard let base = ptr.baseAddress else { return nil }
            return CGContext(
                data: base,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: space,
                bitmapInfo: bitmapInfo
            )
        }
        guard let context = ctx else { return nil }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Un-premultiply so the algorithm sees straight-alpha colors.
        // Use a 256-entry reciprocal table to avoid a Double divide per pixel.
        var reciprocal = [UInt32](repeating: 0, count: 256)
        for a in 1...255 {
            // Fixed-point reciprocal: (255 << 16) / a. Result fits in UInt32.
            reciprocal[a] = UInt32((255 << 16) / a)
        }
        raw.withUnsafeMutableBufferPointer { buf in
            let p = buf.baseAddress!
            let count = buf.count
            var i = 0
            while i < count {
                let a = Int(p[i + 3])
                if a > 0 && a < 255 {
                    let rcp = reciprocal[a]
                    let r = (UInt32(p[i]) &* rcp) >> 16
                    let g = (UInt32(p[i + 1]) &* rcp) >> 16
                    let b = (UInt32(p[i + 2]) &* rcp) >> 16
                    p[i]     = UInt8(min(255, Int(r)))
                    p[i + 1] = UInt8(min(255, Int(g)))
                    p[i + 2] = UInt8(min(255, Int(b)))
                }
                i += 4
            }
        }

        return Bitmap.create(width: width, height: height, bytes: raw)
    }

    /// Renders the bitmap to a `CGImage` for display.
    public func toCGImage() -> CGImage? {
        let bytes = getBytes()
        let bytesPerRow = width * 4
        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            space: space,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}
#endif
