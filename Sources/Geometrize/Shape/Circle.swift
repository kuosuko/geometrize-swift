import Foundation

/// A circle, implemented as an ellipse with equal radii.
public final class Circle: Ellipse {
    public override init(xBound: Int, yBound: Int) {
        super.init(xBound: xBound, yBound: yBound)
        let r = Util.random(below: 32) + 1
        self.rx = r
        self.ry = r
    }

    public override func mutate() {
        switch Util.random(below: 2) {
        case 0:
            x = Util.clamp(x + Util.random(-16, 16), 0, xBound - 1)
            y = Util.clamp(y + Util.random(-16, 16), 0, yBound - 1)
        default:
            let r = Util.clamp(rx + Util.random(-16, 16), 1, xBound - 1)
            rx = r
            ry = r
        }
    }

    public override func clone() -> any Shape {
        let c = Circle(xBound: xBound, yBound: yBound)
        c.x = x; c.y = y; c.rx = rx; c.ry = ry
        return c
    }

    public override func getType() -> ShapeType { .circle }

    public override func getRawShapeData() -> [Double] {
        [Double(x), Double(y), Double(rx)]
    }

    public override func getSvgShapeData() -> String {
        "<circle cx=\"\(x)\" cy=\"\(y)\" r=\"\(rx)\" \(SvgExporter.styleHook) />"
    }
}
