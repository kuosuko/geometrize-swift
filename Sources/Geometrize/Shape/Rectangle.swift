import Foundation

/// An axis-aligned rectangle.
public final class Rectangle: Shape {
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
        self.x2 = Util.clamp(x1 + Util.random(below: 32) + 1, 0, xBound - 1)
        self.y2 = Util.clamp(y1 + Util.random(below: 32) + 1, 0, yBound - 1)
    }

    public func rasterize() -> [Scanline] {
        var lines: [Scanline] = []
        let yMin = min(y1, y2)
        let yMax = max(y1, y2)
        let xLo = min(x1, x2)
        let xHi = max(x1, x2)
        if yMin == yMax {
            lines.append(Scanline(y: yMin, x1: xLo, x2: xHi))
        } else {
            for y in yMin..<yMax {
                lines.append(Scanline(y: y, x1: xLo, x2: xHi))
            }
        }
        return lines
    }

    public func mutate() {
        switch Util.random(below: 2) {
        case 0:
            x1 = Util.clamp(x1 + Util.random(-16, 16), 0, xBound - 1)
            y1 = Util.clamp(y1 + Util.random(-16, 16), 0, yBound - 1)
        default:
            x2 = Util.clamp(x2 + Util.random(-16, 16), 0, xBound - 1)
            y2 = Util.clamp(y2 + Util.random(-16, 16), 0, yBound - 1)
        }
    }

    public func clone() -> any Shape {
        let r = Rectangle(xBound: xBound, yBound: yBound)
        r.x1 = x1; r.y1 = y1; r.x2 = x2; r.y2 = y2
        return r
    }

    public func getType() -> ShapeType { .rectangle }

    public func getRawShapeData() -> [Double] {
        [Double(min(x1, x2)), Double(min(y1, y2)), Double(max(x1, x2)), Double(max(y1, y2))]
    }

    public func getSvgShapeData() -> String {
        let xLo = min(x1, x2)
        let yLo = min(y1, y2)
        let w = max(x1, x2) - xLo
        let h = max(y1, y2) - yLo
        return "<rect x=\"\(xLo)\" y=\"\(yLo)\" width=\"\(w)\" height=\"\(h)\" \(SvgExporter.styleHook) />"
    }
}
