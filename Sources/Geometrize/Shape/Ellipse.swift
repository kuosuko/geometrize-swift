import Foundation

/// An axis-aligned ellipse.
public class Ellipse: Shape {
    public var x: Int
    public var y: Int
    public var rx: Int
    public var ry: Int

    public let xBound: Int
    public let yBound: Int

    public init(xBound: Int, yBound: Int) {
        self.xBound = xBound
        self.yBound = yBound
        self.x = Util.random(below: xBound)
        self.y = Util.random(below: yBound)
        self.rx = Util.random(below: 32) + 1
        self.ry = Util.random(below: 32) + 1
    }

    public func rasterize() -> [Scanline] {
        var lines: [Scanline] = []
        let aspect = Double(rx) / Double(ry)
        let w = xBound
        let h = yBound

        for dy in 0..<ry {
            let y1 = y - dy
            let y2 = y + dy
            if (y1 < 0 || y1 >= h) && (y2 < 0 || y2 >= h) { continue }
            let s = Int(sqrt(Double(ry * ry - dy * dy)) * aspect)
            var x1 = x - s
            var x2 = x + s
            if x1 < 0 { x1 = 0 }
            if x2 >= w { x2 = w - 1 }
            if y1 >= 0 && y1 < h {
                lines.append(Scanline(y: y1, x1: x1, x2: x2))
            }
            if y2 >= 0 && y2 < h && dy > 0 {
                lines.append(Scanline(y: y2, x1: x1, x2: x2))
            }
        }
        return lines
    }

    public func mutate() {
        switch Util.random(below: 3) {
        case 0:
            x = Util.clamp(x + Util.random(-16, 16), 0, xBound - 1)
            y = Util.clamp(y + Util.random(-16, 16), 0, yBound - 1)
        case 1:
            rx = Util.clamp(rx + Util.random(-16, 16), 1, xBound - 1)
        default:
            ry = Util.clamp(ry + Util.random(-16, 16), 1, xBound - 1)
        }
    }

    public func clone() -> any Shape {
        let e = Ellipse(xBound: xBound, yBound: yBound)
        e.x = x; e.y = y; e.rx = rx; e.ry = ry
        return e
    }

    public func getType() -> ShapeType { .ellipse }

    public func getRawShapeData() -> [Double] {
        [Double(x), Double(y), Double(rx), Double(ry)]
    }

    public func getSvgShapeData() -> String {
        "<ellipse cx=\"\(x)\" cy=\"\(y)\" rx=\"\(rx)\" ry=\"\(ry)\" \(SvgExporter.styleHook) />"
    }
}
