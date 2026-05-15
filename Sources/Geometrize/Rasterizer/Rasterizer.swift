import Foundation

/// Rasterization helpers — scanline drawing, copying, Bresenham line generation, and polygon scanlines.
public enum Rasterizer {
    /// Alpha-blends a flat color across the given scanlines.
    public static func drawLines(image: Bitmap, color c: Rgba, lines: [Scanline]) {
        // Precompute the premultiplied source channels.
        var sr = c.r
        sr |= sr << 8
        sr *= c.a
        sr /= 0xFF
        var sg = c.g
        sg |= sg << 8
        sg *= c.a
        sg /= 0xFF
        var sb = c.b
        sb |= sb << 8
        sb *= c.a
        sb /= 0xFF
        var sa = c.a
        sa |= sa << 8

        let m = 65535
        let ma = 65535
        let aCoef = (m - (sa * (ma / m))) * 257
        let width = image.width

        image.withUnsafeMutablePixels { buf in
            guard let base = buf.baseAddress else { return }
            for line in lines {
                let rowStart = base + line.y * width
                let x1 = line.x1
                let x2 = line.x2
                var x = x1
                while x <= x2 {
                    let d = rowStart[x]
                    let dr = Int((d.value >> 24) & 0xFF)
                    let dg = Int((d.value >> 16) & 0xFF)
                    let db = Int((d.value >> 8) & 0xFF)
                    let da = Int(d.value & 0xFF)

                    let r = ((dr * aCoef + sr * ma) / m) >> 8
                    let g = ((dg * aCoef + sg * ma) / m) >> 8
                    let b = ((db * aCoef + sb * ma) / m) >> 8
                    let a = ((da * aCoef + sa * ma) / m) >> 8

                    rowStart[x] = Rgba(uncheckedR: r, g: g, b: b, a: a)
                    x += 1
                }
            }
        }
    }

    /// Copies pixels from `source` into `destination` along the supplied scanlines.
    public static func copyLines(destination: Bitmap, source: Bitmap, lines: [Scanline]) {
        let width = destination.width
        source.withUnsafePixels { src in
            destination.withUnsafeMutablePixels { dst in
                guard let s = src.baseAddress, let d = dst.baseAddress else { return }
                for line in lines {
                    let row = line.y * width
                    let x1 = line.x1
                    let x2 = line.x2
                    let count = x2 - x1 + 1
                    if count > 0 {
                        (d + row + x1).update(from: s + row + x1, count: count)
                    }
                }
            }
        }
    }

    /// Bresenham's line algorithm. Returns the integer pixels along the line from (x1,y1) to (x2,y2).
    public static func bresenham(x1: Int, y1: Int, x2: Int, y2: Int) -> [Point] {
        var x1 = x1
        var y1 = y1

        var dx = x2 - x1
        let ix = (dx > 0 ? 1 : 0) - (dx < 0 ? 1 : 0)
        dx = abs(dx) << 1

        var dy = y2 - y1
        let iy = (dy > 0 ? 1 : 0) - (dy < 0 ? 1 : 0)
        dy = abs(dy) << 1

        var points: [Point] = [Point(x: x1, y: y1)]

        if dx >= dy {
            var error = dy - (dx >> 1)
            while x1 != x2 {
                if error >= 0 && (error != 0 || ix > 0) {
                    error -= dx
                    y1 += iy
                }
                error += dy
                x1 += ix
                points.append(Point(x: x1, y: y1))
            }
        } else {
            var error = dx - (dy >> 1)
            while y1 != y2 {
                if error >= 0 && (error != 0 || iy > 0) {
                    error -= dy
                    x1 += ix
                }
                error += dx
                y1 += iy
                points.append(Point(x: x1, y: y1))
            }
        }
        return points
    }

    /// Converts a polygon (vertices in order) into a set of scanlines describing its filled interior.
    public static func scanlinesForPolygon(_ points: [Point]) -> [Scanline] {
        var edges: [Point] = []
        for i in 0..<points.count {
            let p1 = points[i]
            let p2 = (i == points.count - 1) ? points[0] : points[i + 1]
            edges.append(contentsOf: bresenham(x1: p1.x, y1: p1.y, x2: p2.x, y2: p2.y))
        }

        // Map each y to (min, max) x in a single pass — cheaper than going through Set + minMax.
        var yToMinMax: [Int: (Int, Int)] = [:]
        yToMinMax.reserveCapacity(edges.count)
        for p in edges {
            if let existing = yToMinMax[p.y] {
                yToMinMax[p.y] = (min(existing.0, p.x), max(existing.1, p.x))
            } else {
                yToMinMax[p.y] = (p.x, p.x)
            }
        }

        var lines: [Scanline] = []
        lines.reserveCapacity(yToMinMax.count)
        for (y, mm) in yToMinMax {
            lines.append(Scanline(y: y, x1: mm.0, x2: mm.1))
        }
        return lines
    }
}
