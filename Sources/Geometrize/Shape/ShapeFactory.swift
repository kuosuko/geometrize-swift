import Foundation

/// Factory for constructing fresh random shapes.
public enum ShapeFactory {
    /// Creates a new shape of the requested type, sized for the given canvas bounds.
    public static func create(type: ShapeType, xBound: Int, yBound: Int) -> any Shape {
        switch type {
        case .rectangle:        return Rectangle(xBound: xBound, yBound: yBound)
        case .rotatedRectangle: return RotatedRectangle(xBound: xBound, yBound: yBound)
        case .triangle:         return Triangle(xBound: xBound, yBound: yBound)
        case .ellipse:          return Ellipse(xBound: xBound, yBound: yBound)
        case .rotatedEllipse:   return RotatedEllipse(xBound: xBound, yBound: yBound)
        case .circle:           return Circle(xBound: xBound, yBound: yBound)
        case .line:             return Line(xBound: xBound, yBound: yBound)
        case .quadraticBezier:  return QuadraticBezier(xBound: xBound, yBound: yBound)
        }
    }

    /// Creates a random shape of any supported type.
    public static func randomShape(xBound: Int, yBound: Int) -> any Shape {
        create(type: Util.randomArrayItem(ShapeType.allCases), xBound: xBound, yBound: yBound)
    }

    /// Creates a random shape picked from the supplied types.
    public static func randomShape(of types: [ShapeType], xBound: Int, yBound: Int) -> any Shape {
        create(type: Util.randomArrayItem(types), xBound: xBound, yBound: yBound)
    }
}
