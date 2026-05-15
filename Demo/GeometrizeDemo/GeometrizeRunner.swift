import Foundation
import SwiftUI
import Geometrize

/// Phase of the editing session — drives EditView's visual state and which controls show.
enum RunPhase: Equatable {
    case idle           // Source loaded, nothing started yet
    case drawing        // Shapes accumulating; image card shows the live canvas
    case done           // Run completed (either by hitting target count or user stop)
}

/// View-model that owns the algorithm runner and exposes a small, focused surface to the UI.
@MainActor
final class GeometrizeRunner: ObservableObject {
    struct StyleSummary {
        let label: String
        let detail: String
    }

    @Published var sourceImage: UIImage?
    @Published var resultImage: UIImage?
    @Published var phase: RunPhase = .idle
    @Published var shapeCount: Int = 0
    @Published var score: Double = 0

    // Positional pad (0..1, 0..1) — see derivedParameters() for what the corners mean.
    @Published var padPosition: CGPoint = .init(x: 0.5, y: 0.5) {
        didSet { refreshStyleSummary() }
    }
    @Published var shapeTypes: Set<ShapeType> = [.triangle, .rotatedEllipse]
    @Published private(set) var currentStyleSummary = StyleSummary(label: "Balanced", detail: "A solid all-rounder")

    // Manual overrides — exposed when the user opens "Advanced". When `useOverrides` is true
    // these win over the pad position.
    @Published var useOverrides = false {
        didSet { refreshStyleSummary() }
    }
    @Published var alphaOverride: Double = 128
    @Published var candidatesOverride: Double = 50
    @Published var mutationsOverride: Double = 100
    @Published var maxDimensionOverride: Double = 256
    @Published var useTargetCountOverride = false
    @Published var targetCountOverride: Double = 500

    private var runner: ImageRunner?
    private var collectedShapes: [ShapeResult] = []
    private var fitWidth = 0
    private var fitHeight = 0
    private var task: Task<Void, Never>?

    // MARK: - Public surface

    func loadImage(_ image: UIImage) {
        task?.cancel()
        sourceImage = image
        resultImage = nil
        runner = nil
        collectedShapes = []
        shapeCount = 0
        score = 0
        phase = .idle
    }

    func start() {
        guard phase != .drawing, let image = sourceImage, let cg = image.cgImage else { return }
        let params = derivedParameters()
        guard let bitmap = Bitmap.from(cgImage: cg, maxDimension: params.maxDimension) else { return }

        let runner = ImageRunner(inputImage: bitmap, backgroundColor: bitmap.averageColor())
        self.runner = runner
        self.fitWidth = bitmap.width
        self.fitHeight = bitmap.height
        self.collectedShapes = []
        self.shapeCount = 0
        // Seed the result image with the blank background so the canvas starts blank,
        // not as the source image.
        if let blank = runner.imageData.toCGImage() {
            self.resultImage = UIImage(cgImage: blank)
        }
        self.phase = .drawing

        let optionsSnapshot = ImageRunnerOptions(
            shapeTypes: shapeTypes.isEmpty ? [.triangle] : Array(shapeTypes),
            alpha: params.alpha,
            candidateShapesPerStep: params.candidates,
            shapeMutationsPerStep: params.mutations
        )
        let cap = params.targetCount

        task = Task.detached(priority: .userInitiated) { [weak self] in
            await self?.loop(options: optionsSnapshot, targetCount: cap)
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        if phase == .drawing { phase = .done }
    }

    /// Reset back to the original image, discarding the run.
    func reset() {
        task?.cancel()
        task = nil
        runner = nil
        collectedShapes = []
        shapeCount = 0
        score = 0
        resultImage = nil
        phase = .idle
    }

    // MARK: - Style summary

    func styleSummary() -> StyleSummary {
        currentStyleSummary
    }

    private func refreshStyleSummary() {
        currentStyleSummary = resolvedStyleSummary()
    }

    private func resolvedStyleSummary() -> StyleSummary {
        if useOverrides { return StyleSummary(label: "Custom", detail: "Manual sliders") }
        let x = padPosition.x, y = padPosition.y
        let dx = abs(x - 0.5), dy = abs(y - 0.5)
        if dx < 0.18 && dy < 0.18 {
            return StyleSummary(label: "Balanced", detail: "A solid all-rounder")
        }
        switch (x < 0.5, y < 0.5) {
        case (true, true):   return StyleSummary(label: "Speed",   detail: "Quick preview, fewer shapes")
        case (false, true):  return StyleSummary(label: "Quality", detail: "Refined fits per shape")
        case (true, false):  return StyleSummary(label: "Sparse",  detail: "Few opaque shapes, stylized")
        case (false, false): return StyleSummary(label: "Dense",   detail: "Many translucent shapes")
        }
    }

    // MARK: - Export

    func exportSVG() -> String {
        SvgExporter.export(shapes: collectedShapes, width: fitWidth, height: fitHeight)
    }
    func exportJSON() -> String {
        ShapeJsonExporter.export(collectedShapes)
    }

    // MARK: - Parameter derivation

    struct DerivedParameters {
        let alpha: Int
        let candidates: Int
        let mutations: Int
        let targetCount: Int
        let maxDimension: Int
    }

    /// Pad corners:
    /// - TL (0,0) Speed:   light everything, ~150 target, max dim 192
    /// - TR (1,0) Quality: high cand+mut, medium target, max dim 320
    /// - BL (0,1) Sparse:  high alpha (opaque), low candidates, low target
    /// - BR (1,1) Dense:   low alpha (translucent), many shapes, high target
    func derivedParameters() -> DerivedParameters {
        let padParameters = padDerivedParameters()
        if useOverrides {
            return DerivedParameters(
                alpha: Int(alphaOverride),
                candidates: Int(candidatesOverride),
                mutations: Int(mutationsOverride),
                targetCount: Int(targetCountOverride),
                maxDimension: Int(maxDimensionOverride)
            )
        }
        if useTargetCountOverride {
            return DerivedParameters(
                alpha: padParameters.alpha,
                candidates: padParameters.candidates,
                mutations: padParameters.mutations,
                targetCount: Int(targetCountOverride),
                maxDimension: padParameters.maxDimension
            )
        }
        return padParameters
    }

    private func padDerivedParameters() -> DerivedParameters {
        let x = max(0, min(1, padPosition.x))
        let y = max(0, min(1, padPosition.y))
        return DerivedParameters(
            alpha: Int(lerp(140, 140, 220, 100, x, y).rounded()),
            candidates: Int(lerp(25, 100, 40, 90, x, y).rounded()),
            mutations: Int(lerp(40, 180, 60, 140, x, y).rounded()),
            targetCount: Int(lerp(150, 500, 100, 1200, x, y).rounded()),
            maxDimension: Int(lerp(192, 320, 256, 320, x, y).rounded())
        )
    }

    private func lerp(_ tl: Double, _ tr: Double, _ bl: Double, _ br: Double, _ x: Double, _ y: Double) -> Double {
        let top = tl * (1 - x) + tr * x
        let bot = bl * (1 - x) + br * x
        return top * (1 - y) + bot * y
    }

    // MARK: - Loop

    private func loop(options: ImageRunnerOptions, targetCount: Int) async {
        guard let runner = self.runner else { return }
        while !Task.isCancelled {
            let stepResults = runner.step(options)
            let snapshot = runner.imageData.clone()
            let stop: Bool = await MainActor.run {
                self.collectedShapes.append(contentsOf: stepResults)
                self.shapeCount = self.collectedShapes.count
                if let last = stepResults.last { self.score = last.score }
                if let cg = snapshot.toCGImage() {
                    self.resultImage = UIImage(cgImage: cg)
                }
                return targetCount > 0 && self.collectedShapes.count >= targetCount
            }
            if stop { break }
            await Task.yield()
        }
        await MainActor.run {
            if self.phase == .drawing { self.phase = .done }
        }
    }
}
