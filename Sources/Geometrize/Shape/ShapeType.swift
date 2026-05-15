import Foundation

/// The shape primitives Geometrize can fit to a target image.
public enum ShapeType: Int, CaseIterable, Sendable {
    case rectangle = 0
    case rotatedRectangle = 1
    case triangle = 2
    case ellipse = 3
    case rotatedEllipse = 4
    case circle = 5
    case line = 6
    case quadraticBezier = 7
}
