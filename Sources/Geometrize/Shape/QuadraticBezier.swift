import Foundation

/// A quadratic Bézier curve, sampled at 20 points and rasterized as a 1-pixel-wide stroke.
public final class QuadraticBezier: Shape {
    public var cx: Int
    public var cy: Int
    public var x1: Int
    public var y1: Int
    public var x2: Int
    public var y2: Int

    public let xBound: Int
    public let yBound: Int

    public init(xBound: Int, yBound: Int) {
        self.xBound = xBound
        self.yBound = yBound
        self.x1 = Util.random(0, xBound - 1)
        self.y1 = Util.random(0, yBound - 1)
        self.cx = Util.random(0, xBound - 1)
        self.cy = Util.random(0, yBound - 1)
        self.x2 = Util.random(0, xBound - 1)
        self.y2 = Util.random(0, yBound - 1)
    }

    public func rasterize() -> [Scanline] {
        var lines: [Scanline] = []
        var points: [Point] = []
        let pointCount = 20

        for i in 0..<(pointCount - 1) {
            let t = Double(i) / Double(pointCount)
            let tp = 1 - t
            let x = Int(tp * (tp * Double(x1) + (t * Double(cx))) + t * ((tp * Double(cx)) + (t * Double(x2))))
            let y = Int(tp * (tp * Double(y1) + (t * Double(cy))) + t * ((tp * Double(cy)) + (t * Double(y2))))
            points.append(Point(x: x, y: y))
        }

        for i in 0..<(points.count - 1) {
            let p0 = points[i]
            let p1 = points[i + 1]
            let pts = Rasterizer.bresenham(x1: p0.x, y1: p0.y, x2: p1.x, y2: p1.y)
            for point in pts {
                if let last = lines.last,
                   last.y == point.y, last.x1 == point.x, last.x2 == point.x {
                    continue
                }
                lines.append(Scanline(y: point.y, x1: point.x, x2: point.x))
            }
        }

        return Scanline.trim(lines, width: xBound, height: yBound)
    }

    public func mutate() {
        switch Util.random(0, 2) {
        case 0:
            cx = Util.clamp(cx + Util.random(-8, 8), 0, xBound - 1)
            cy = Util.clamp(cy + Util.random(-8, 8), 0, yBound - 1)
        case 1:
            x1 = Util.clamp(x1 + Util.random(-8, 8), 1, xBound - 1)
            y1 = Util.clamp(y1 + Util.random(-8, 8), 1, yBound - 1)
        default:
            x2 = Util.clamp(x2 + Util.random(-8, 8), 1, xBound - 1)
            y2 = Util.clamp(y2 + Util.random(-8, 8), 1, yBound - 1)
        }
    }

    public func clone() -> any Shape {
        let b = QuadraticBezier(xBound: xBound, yBound: yBound)
        b.cx = cx; b.cy = cy; b.x1 = x1; b.y1 = y1; b.x2 = x2; b.y2 = y2
        return b
    }

    public func getType() -> ShapeType { .quadraticBezier }

    public func getRawShapeData() -> [Double] {
        [Double(x1), Double(y1), Double(cx), Double(cy), Double(x2), Double(y2)]
    }

    public func getSvgShapeData() -> String {
        "<path d=\"M\(x1) \(y1) Q \(cx) \(cy) \(x2) \(y2)\" \(SvgExporter.styleHook) />"
    }
}
