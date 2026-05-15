import Foundation

/// Result of fitting a single shape — its final color, the shape itself, and the resulting score.
public struct ShapeResult {
    public let score: Double
    public let color: Rgba
    public let shape: any Shape

    public init(score: Double, color: Rgba, shape: any Shape) {
        self.score = score
        self.color = color
        self.shape = shape
    }
}

/// The optimization model — owns the target image and the current best approximation.
public final class Model {
    public let width: Int
    public let height: Int
    public let target: Bitmap
    public private(set) var current: Bitmap
    public private(set) var buffer: Bitmap
    private var score: Double

    public init(target: Bitmap, backgroundColor: Rgba) {
        self.width = target.width
        self.height = target.height
        self.target = target
        self.current = Bitmap.create(width: target.width, height: target.height, color: backgroundColor)
        self.buffer = Bitmap.create(width: target.width, height: target.height, color: backgroundColor)
        self.score = Core.differenceFull(first: target, second: current)
    }

    /// Runs one optimization step and adds the best shape found to `current`.
    public func step(shapeTypes: [ShapeType], alpha: Int, candidateShapes n: Int, mutationsPerShape age: Int) -> [ShapeResult] {
        let state = Core.bestHillClimbState(
            shapes: shapeTypes, alpha: alpha, n: n, age: age,
            target: target, current: current, buffer: buffer, lastScore: score
        )
        return [addShape(state.shape, alpha: state.alpha)]
    }

    /// Adds a specific shape to the model and updates the running score.
    @discardableResult
    public func addShape(_ shape: any Shape, alpha: Int) -> ShapeResult {
        let before = current.clone()
        let lines = shape.rasterize()
        let color = Core.computeColor(target: target, current: current, lines: lines, alpha: alpha)
        Rasterizer.drawLines(image: current, color: color, lines: lines)
        score = Core.differencePartial(target: target, before: before, after: current, score: score, lines: lines)
        return ShapeResult(score: score, color: color, shape: shape)
    }

    /// The current RMS error against the target, in `[0, 1]`. Lower is closer to the target.
    public var currentScore: Double { score }
}
