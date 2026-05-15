import Foundation

/// Tunables for `ImageRunner.step(_:)`.
public struct ImageRunnerOptions: Sendable {
    /// Allowed shape types — at least one must be supplied.
    public var shapeTypes: [ShapeType]
    /// Opacity of each placed shape (0–255).
    public var alpha: Int
    /// Random shapes generated per step before hill-climbing.
    public var candidateShapesPerStep: Int
    /// Hill-climbing mutations attempted per candidate.
    public var shapeMutationsPerStep: Int

    public init(
        shapeTypes: [ShapeType] = [.triangle],
        alpha: Int = 128,
        candidateShapesPerStep: Int = 50,
        shapeMutationsPerStep: Int = 100
    ) {
        self.shapeTypes = shapeTypes
        self.alpha = alpha
        self.candidateShapesPerStep = candidateShapesPerStep
        self.shapeMutationsPerStep = shapeMutationsPerStep
    }

    public static let `default` = ImageRunnerOptions()
}
