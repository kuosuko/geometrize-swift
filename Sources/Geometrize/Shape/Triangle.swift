import Foundation

/// A triangle with three independently mutable vertices.
public final class Triangle: Shape {
    public var x1: Int
    public var y1: Int
    public var x2: Int
    public var y2: Int
    public var x3: Int
    public var y3: Int

    public let xBound: Int
    public let yBound: Int

    public init(xBound: Int, yBound: Int) {
        self.xBound = xBound
        self.yBound = yBound
        self.x1 = Util.random(below: xBound)
        self.y1 = Util.random(below: yBound)
        self.x2 = x1 + Util.random(-16, 16)
        self.y2 = y1 + Util.random(-16, 16)
        self.x3 = x1 + Util.random(-16, 16)
        self.y3 = y1 + Util.random(-16, 16)
    }

    public func rasterize() -> [Scanline] {
        Scanline.trim(
            Rasterizer.scanlinesForPolygon([
                Point(x: x1, y: y1),
                Point(x: x2, y: y2),
                Point(x: x3, y: y3)
            ]),
            width: xBound, height: yBound
        )
    }

    public func mutate() {
        switch Util.random(below: 3) {
        case 0:
            x1 = Util.clamp(x1 + Util.random(-16, 16), 0, xBound - 1)
            y1 = Util.clamp(y1 + Util.random(-16, 16), 0, yBound - 1)
        case 1:
            x2 = Util.clamp(x2 + Util.random(-16, 16), 0, xBound - 1)
            y2 = Util.clamp(y2 + Util.random(-16, 16), 0, yBound - 1)
        default:
            x3 = Util.clamp(x3 + Util.random(-16, 16), 0, xBound - 1)
            y3 = Util.clamp(y3 + Util.random(-16, 16), 0, yBound - 1)
        }
    }

    public func clone() -> any Shape {
        let t = Triangle(xBound: xBound, yBound: yBound)
        t.x1 = x1; t.y1 = y1; t.x2 = x2; t.y2 = y2; t.x3 = x3; t.y3 = y3
        return t
    }

    public func getType() -> ShapeType { .triangle }

    public func getRawShapeData() -> [Double] {
        [Double(x1), Double(y1), Double(x2), Double(y2), Double(x3), Double(y3)]
    }

    public func getSvgShapeData() -> String {
        "<polygon points=\"\(x1),\(y1) \(x2),\(y2) \(x3),\(y3)\" \(SvgExporter.styleHook)/>"
    }
}
