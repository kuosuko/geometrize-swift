import Foundation

/// A geometric primitive that can be rasterized and mutated as part of the fitting algorithm.
///
/// Shapes use reference semantics because the hill-climbing optimizer mutates them in place,
/// then restores the previous state if the mutation didn't improve the fit.
public protocol Shape: AnyObject {
    /// The canvas width the shape was initialized against.
    var xBound: Int { get }
    /// The canvas height the shape was initialized against.
    var yBound: Int { get }

    /// Produces the scanlines covering the shape.
    func rasterize() -> [Scanline]
    /// Applies a small random change to the shape.
    func mutate()
    /// Deep copy.
    func clone() -> any Shape
    /// The shape's type tag.
    func getType() -> ShapeType
    /// A flat numeric description of the shape geometry (format depends on type).
    func getRawShapeData() -> [Double]
    /// An SVG element string describing the geometry; styling is filled in by the exporter.
    func getSvgShapeData() -> String
}
