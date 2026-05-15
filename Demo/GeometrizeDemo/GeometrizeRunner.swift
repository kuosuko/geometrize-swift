import Foundation
import SwiftUI
import Geometrize

/// How the starting background color is chosen for the approximation.
enum BackgroundMode: String, CaseIterable, Identifiable {
    case averageOfImage = "Average"
    case white = "White"
    case black = "Black"
    case custom = "Custom"
    var id: String { rawValue }
}

/// View-model that owns an `ImageRunner` and drives it from a background task,
/// publishing progress so SwiftUI can render the evolving approximation.
@MainActor
final class GeometrizeRunner: ObservableObject {
    @Published var sourceImage: UIImage?
    @Published var resultImage: UIImage?
    @Published var shapeCount: Int = 0
    @Published var score: Double = 0
    @Published var isRunning = false

    // Tunables surfaced to the UI.
    @Published var shapeTypes: Set<ShapeType> = [.triangle]
    @Published var alpha: Double = 128
    @Published var candidatesPerStep: Double = 50
    @Published var mutationsPerStep: Double = 100
    @Published var maxDimension: Double = 256
    @Published var shapesPerBatch: Double = 1      // Steps to run before UI refresh
    @Published var targetShapeCount: Double = 500  // Auto-stop after this many shapes (0 = unlimited)

    @Published var backgroundMode: BackgroundMode = .averageOfImage
    @Published var customBackgroundColor: Color = .white

    private var runner: ImageRunner?
    private var collectedShapes: [ShapeResult] = []
    private var fitWidth = 0
    private var fitHeight = 0
    private var task: Task<Void, Never>?

    func loadImage(_ image: UIImage) {
        task?.cancel()
        sourceImage = image
        resultImage = nil
        runner = nil
        collectedShapes = []
        shapeCount = 0
        score = 0
    }

    func resetDefaults() {
        shapeTypes = [.triangle]
        alpha = 128
        candidatesPerStep = 50
        mutationsPerStep = 100
        maxDimension = 256
        shapesPerBatch = 1
        targetShapeCount = 500
        backgroundMode = .averageOfImage
        customBackgroundColor = .white
    }

    func applyPreset(_ preset: Preset) {
        shapeTypes = preset.shapeTypes
        alpha = Double(preset.alpha)
        candidatesPerStep = Double(preset.candidates)
        mutationsPerStep = Double(preset.mutations)
        targetShapeCount = Double(preset.targetCount)
    }

    func start() {
        guard !isRunning, let image = sourceImage, let cg = image.cgImage else { return }

        let cap = Int(maxDimension)
        guard let bitmap = Bitmap.from(cgImage: cg, maxDimension: cap) else { return }

        let bg = backgroundColor(for: bitmap)
        let runner = ImageRunner(inputImage: bitmap, backgroundColor: bg)
        self.runner = runner
        self.fitWidth = bitmap.width
        self.fitHeight = bitmap.height
        self.collectedShapes = []
        self.shapeCount = 0

        let optionsSnapshot = ImageRunnerOptions(
            shapeTypes: shapeTypes.isEmpty ? [.triangle] : Array(shapeTypes),
            alpha: Int(alpha),
            candidateShapesPerStep: Int(candidatesPerStep),
            shapeMutationsPerStep: Int(mutationsPerStep)
        )
        let batch = max(1, Int(shapesPerBatch))
        let cap2 = Int(targetShapeCount)

        isRunning = true
        task = Task.detached(priority: .userInitiated) { [weak self] in
            await self?.loop(options: optionsSnapshot, batchSize: batch, targetCount: cap2)
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        isRunning = false
    }

    func exportSVG() -> String {
        SvgExporter.export(shapes: collectedShapes, width: fitWidth, height: fitHeight)
    }

    func exportJSON() -> String {
        ShapeJsonExporter.export(collectedShapes)
    }

    // MARK: - Internals

    private func backgroundColor(for bitmap: Bitmap) -> Rgba {
        switch backgroundMode {
        case .averageOfImage: return bitmap.averageColor()
        case .white: return Rgba.opaqueWhite
        case .black: return Rgba.opaqueBlack
        case .custom: return customBackgroundColor.toRgba()
        }
    }

    private func loop(options: ImageRunnerOptions, batchSize: Int, targetCount: Int) async {
        guard let runner = self.runner else { return }
        while !Task.isCancelled {
            var batchResults: [ShapeResult] = []
            for _ in 0..<batchSize {
                let step = runner.step(options)
                batchResults.append(contentsOf: step)
                if Task.isCancelled { break }
            }
            let snapshot = runner.imageData.clone()
            let shouldStop: Bool = await MainActor.run {
                self.collectedShapes.append(contentsOf: batchResults)
                self.shapeCount = self.collectedShapes.count
                if let last = batchResults.last { self.score = last.score }
                if let cg = snapshot.toCGImage() {
                    self.resultImage = UIImage(cgImage: cg)
                }
                return targetCount > 0 && self.collectedShapes.count >= targetCount
            }
            if shouldStop { break }
            await Task.yield()
        }
        await MainActor.run { self.isRunning = false }
    }
}

extension Color {
    /// Converts a SwiftUI Color to the library's RGBA8888 type via UIColor.
    func toRgba() -> Rgba {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return Rgba(
            r: Int((r * 255).rounded()),
            g: Int((g * 255).rounded()),
            b: Int((b * 255).rounded()),
            a: Int((a * 255).rounded())
        )
    }
}

/// Named presets to make the parameter space easier to explore.
struct Preset: Identifiable {
    let id = UUID()
    let name: String
    let detail: String
    let shapeTypes: Set<ShapeType>
    let alpha: Int
    let candidates: Int
    let mutations: Int
    let targetCount: Int

    static let all: [Preset] = [
        Preset(name: "Fast preview",
               detail: "Triangles, low quality, ~150 shapes",
               shapeTypes: [.triangle],
               alpha: 128, candidates: 30, mutations: 50, targetCount: 150),
        Preset(name: "Balanced",
               detail: "Triangles + rotated ellipses, 500 shapes",
               shapeTypes: [.triangle, .rotatedEllipse],
               alpha: 128, candidates: 50, mutations: 100, targetCount: 500),
        Preset(name: "High quality",
               detail: "All shapes, more candidates, 800 shapes",
               shapeTypes: Set(ShapeType.allCases),
               alpha: 128, candidates: 100, mutations: 200, targetCount: 800),
        Preset(name: "Stained glass",
               detail: "Rotated rectangles, opaque, 400 shapes",
               shapeTypes: [.rotatedRectangle],
               alpha: 200, candidates: 60, mutations: 120, targetCount: 400),
        Preset(name: "Linework",
               detail: "Lines + Béziers, semi-transparent",
               shapeTypes: [.line, .quadraticBezier],
               alpha: 90, candidates: 80, mutations: 150, targetCount: 600)
    ]
}
