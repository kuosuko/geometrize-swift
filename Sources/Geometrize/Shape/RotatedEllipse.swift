import Foundation

/// An ellipse rotated about its centre.
public final class RotatedEllipse: Shape {
    public var x: Int
    public var y: Int
    public var rx: Int
    public var ry: Int
    public var angle: Int

    public let xBound: Int
    public let yBound: Int

    public init(xBound: Int, yBound: Int) {
        self.xBound = xBound
        self.yBound = yBound
        self.x = Util.random(below: xBound)
        self.y = Util.random(below: yBound)
        self.rx = Util.random(below: 32) + 1
        self.ry = Util.random(below: 32) + 1
        self.angle = Util.random(below: 360)
    }

    public func rasterize() -> [Scanline] {
        let pointCount = 20
        var points: [Point] = []
        points.reserveCapacity(pointCount)

        let rads = Double(angle) * (.pi / 180.0)
        let c = cos(rads)
        let s = sin(rads)

        for i in 0..<pointCount {
            let rot = (360.0 / Double(pointCount)) * Double(i) * (.pi / 180.0)
            let crx = Double(rx) * cos(rot)
            let cry = Double(ry) * sin(rot)

            let tx = Int(crx * c - cry * s + Double(x))
            let ty = Int(crx * s + cry * c + Double(y))
            points.append(Point(x: tx, y: ty))
        }

        return Scanline.trim(Rasterizer.scanlinesForPolygon(points), width: xBound, height: yBound)
    }

    public func mutate() {
        switch Util.random(below: 4) {
        case 0:
            x = Util.clamp(x + Util.random(-16, 16), 0, xBound - 1)
            y = Util.clamp(y + Util.random(-16, 16), 0, yBound - 1)
        case 1:
            rx = Util.clamp(rx + Util.random(-16, 16), 1, xBound - 1)
        case 2:
            ry = Util.clamp(ry + Util.random(-16, 16), 1, yBound - 1)
        default:
            angle = Util.clamp(angle + Util.random(-4, 4), 0, 360)
        }
    }

    public func clone() -> any Shape {
        let e = RotatedEllipse(xBound: xBound, yBound: yBound)
        e.x = x; e.y = y; e.rx = rx; e.ry = ry; e.angle = angle
        return e
    }

    public func getType() -> ShapeType { .rotatedEllipse }

    public func getRawShapeData() -> [Double] {
        [Double(x), Double(y), Double(rx), Double(ry), Double(angle)]
    }

    public func getSvgShapeData() -> String {
        var s = "<g transform=\"translate(\(x) \(y)) rotate(\(angle)) scale(\(rx) \(ry))\">"
        s += "<ellipse cx=\"0\" cy=\"0\" rx=\"1\" ry=\"1\" \(SvgExporter.styleHook) />"
        s += "</g>"
        return s
    }
}
