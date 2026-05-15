import Foundation

/// A rectangle rotated about its centre.
public final class RotatedRectangle: Shape {
    public var x1: Int
    public var y1: Int
    public var x2: Int
    public var y2: Int
    public var angle: Int

    public let xBound: Int
    public let yBound: Int

    public init(xBound: Int, yBound: Int) {
        self.xBound = xBound
        self.yBound = yBound
        self.x1 = Util.random(below: xBound)
        self.y1 = Util.random(below: yBound)
        self.x2 = Util.clamp(x1 + Util.random(below: 32) + 1, 0, xBound)
        self.y2 = Util.clamp(y1 + Util.random(below: 32) + 1, 0, yBound)
        self.angle = Util.random(0, 360)
    }

    public func rasterize() -> [Scanline] {
        Scanline.trim(Rasterizer.scanlinesForPolygon(getCornerPoints()), width: xBound, height: yBound)
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
            angle = Util.clamp(angle + Util.random(-4, 4), 0, 360)
        }
    }

    public func clone() -> any Shape {
        let r = RotatedRectangle(xBound: xBound, yBound: yBound)
        r.x1 = x1; r.y1 = y1; r.x2 = x2; r.y2 = y2; r.angle = angle
        return r
    }

    public func getType() -> ShapeType { .rotatedRectangle }

    public func getRawShapeData() -> [Double] {
        [Double(min(x1, x2)), Double(min(y1, y2)), Double(max(x1, x2)), Double(max(y1, y2)), Double(angle)]
    }

    public func getSvgShapeData() -> String {
        let pts = getCornerPoints()
        var s = "<polygon points=\""
        for (i, p) in pts.enumerated() {
            s += "\(p.x) \(p.y)"
            if i != pts.count - 1 { s += " " }
        }
        s += "\" \(SvgExporter.styleHook)/>"
        return s
    }

    private func getCornerPoints() -> [Point] {
        let xm1 = min(x1, x2)
        let xm2 = max(x1, x2)
        let ym1 = min(y1, y2)
        let ym2 = max(y1, y2)

        let cx = (xm1 + xm2) / 2
        let cy = (ym1 + ym2) / 2

        let ox1 = xm1 - cx
        let ox2 = xm2 - cx
        let oy1 = ym1 - cy
        let oy2 = ym2 - cy

        let rads = Double(angle) * .pi / 180
        let c = cos(rads)
        let s = sin(rads)

        let ulx = Int(Double(ox1) * c - Double(oy1) * s + Double(cx))
        let uly = Int(Double(ox1) * s + Double(oy1) * c + Double(cy))
        let blx = Int(Double(ox1) * c - Double(oy2) * s + Double(cx))
        let bly = Int(Double(ox1) * s + Double(oy2) * c + Double(cy))
        let urx = Int(Double(ox2) * c - Double(oy1) * s + Double(cx))
        let ury = Int(Double(ox2) * s + Double(oy1) * c + Double(cy))
        let brx = Int(Double(ox2) * c - Double(oy2) * s + Double(cx))
        let bry = Int(Double(ox2) * s + Double(oy2) * c + Double(cy))

        return [
            Point(x: ulx, y: uly),
            Point(x: urx, y: ury),
            Point(x: brx, y: bry),
            Point(x: blx, y: bly)
        ]
    }
}
