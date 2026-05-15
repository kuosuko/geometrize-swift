import Foundation

/// A 1-pixel-wide line segment.
public final class Line: Shape {
    public var x1: Int
    public var y1: Int
    public var x2: Int
    public var y2: Int

    public let xBound: Int
    public let yBound: Int

    public init(xBound: Int, yBound: Int) {
        self.xBound = xBound
        self.yBound = yBound
        self.x1 = Util.random(below: xBound)
        self.y1 = Util.random(below: yBound)
        self.x2 = Util.clamp(x1 + Util.random(below: 32) + 1, 0, xBound)
        self.y2 = Util.clamp(y1 + Util.random(below: 32) + 1, 0, yBound)
    }

    public func rasterize() -> [Scanline] {
        var lines: [Scanline] = []
        let points = Rasterizer.bresenham(x1: x1, y1: y1, x2: x2, y2: y2)
        for p in points {
            lines.append(Scanline(y: p.y, x1: p.x, x2: p.x))
        }
        return Scanline.trim(lines, width: xBound, height: yBound)
    }

    public func mutate() {
        // Original library uses Std.random(4) but only handles cases 0/1; preserving that behaviour.
        switch Util.random(below: 4) {
        case 0:
            x1 = Util.clamp(x1 + Util.random(-16, 16), 0, xBound - 1)
            y1 = Util.clamp(y1 + Util.random(-16, 16), 0, yBound - 1)
        case 1:
            x2 = Util.clamp(x2 + Util.random(-16, 16), 0, xBound - 1)
            y2 = Util.clamp(y2 + Util.random(-16, 16), 0, yBound - 1)
        default:
            break
        }
    }

    public func clone() -> any Shape {
        let l = Line(xBound: xBound, yBound: yBound)
        l.x1 = x1; l.y1 = y1; l.x2 = x2; l.y2 = y2
        return l
    }

    public func getType() -> ShapeType { .line }

    public func getRawShapeData() -> [Double] {
        [Double(x1), Double(y1), Double(x2), Double(y2)]
    }

    public func getSvgShapeData() -> String {
        "<line x1=\"\(x1)\" y1=\"\(y1)\" x2=\"\(x2)\" y2=\"\(y2)\" \(SvgExporter.styleHook) />"
    }
}
