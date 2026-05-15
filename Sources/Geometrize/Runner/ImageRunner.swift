import Foundation

/// High-level wrapper around `Model` for stepping through a fit.
public final class ImageRunner {
    public let model: Model

    public init(inputImage: Bitmap, backgroundColor: Rgba) {
        self.model = Model(target: inputImage, backgroundColor: backgroundColor)
    }

    /// Runs one step of the algorithm and returns info about the shape(s) added.
    @discardableResult
    public func step(_ options: ImageRunnerOptions) -> [ShapeResult] {
        let shapeTypes = options.shapeTypes.isEmpty ? ImageRunnerOptions.default.shapeTypes : options.shapeTypes
        return model.step(
            shapeTypes: shapeTypes,
            alpha: options.alpha,
            candidateShapes: options.candidateShapesPerStep,
            mutationsPerShape: options.shapeMutationsPerStep
        )
    }

    /// The current approximation of the target image.
    public var imageData: Bitmap { model.current }
}
