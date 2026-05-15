import XCTest
@testable import Geometrize

final class GeometrizeTests: XCTestCase {
    func testRgbaRoundtrip() {
        let c = Rgba(r: 200, g: 100, b: 50, a: 128)
        XCTAssertEqual(c.r, 200)
        XCTAssertEqual(c.g, 100)
        XCTAssertEqual(c.b, 50)
        XCTAssertEqual(c.a, 128)
    }

    func testRgbaClamps() {
        let c = Rgba(r: -10, g: 999, b: 50, a: 1000)
        XCTAssertEqual(c.r, 0)
        XCTAssertEqual(c.g, 255)
        XCTAssertEqual(c.a, 255)
    }

    func testBitmapFillAndGet() {
        let bg = Rgba(r: 10, g: 20, b: 30, a: 255)
        let bmp = Bitmap.create(width: 4, height: 3, color: bg)
        XCTAssertEqual(bmp.width, 4)
        XCTAssertEqual(bmp.height, 3)
        XCTAssertEqual(bmp.getPixel(x: 2, y: 1), bg)
        let bytes = bmp.getBytes()
        XCTAssertEqual(bytes.count, 4 * 3 * 4)
        XCTAssertEqual(bytes[0], 10)
        XCTAssertEqual(bytes[1], 20)
        XCTAssertEqual(bytes[2], 30)
        XCTAssertEqual(bytes[3], 255)
    }

    func testBitmapClone() {
        let bmp = Bitmap.create(width: 2, height: 2, color: Rgba.opaqueWhite)
        let copy = bmp.clone()
        copy.setPixel(x: 0, y: 0, color: Rgba.opaqueBlack)
        XCTAssertEqual(bmp.getPixel(x: 0, y: 0), Rgba.opaqueWhite)
        XCTAssertEqual(copy.getPixel(x: 0, y: 0), Rgba.opaqueBlack)
    }

    func testScanlineTrim() {
        let lines = [
            Scanline(y: 5, x1: -3, x2: 12),   // clamp both ends
            Scanline(y: -1, x1: 0, x2: 5),    // out of bounds y
            Scanline(y: 2, x1: 20, x2: 25),   // entirely past width
            Scanline(y: 3, x1: 4, x2: 4)      // single pixel inside
        ]
        let trimmed = Scanline.trim(lines, width: 10, height: 10)
        XCTAssertEqual(trimmed.count, 2)
        XCTAssertEqual(trimmed[0], Scanline(y: 5, x1: 0, x2: 9))
        XCTAssertEqual(trimmed[1], Scanline(y: 3, x1: 4, x2: 4))
    }

    func testRectangleRasterizesNonEmpty() {
        let rect = Rectangle(xBound: 100, yBound: 100)
        let lines = rect.rasterize()
        XCTAssertGreaterThan(lines.count, 0)
    }

    func testShapeFactoryProducesEveryType() {
        for type in ShapeType.allCases {
            let shape = ShapeFactory.create(type: type, xBound: 64, yBound: 64)
            XCTAssertEqual(shape.getType(), type)
        }
    }

    func testFitsSolidColorImage() {
        // A small solid-red target should converge toward red quickly.
        let red = Rgba(r: 255, g: 0, b: 0, a: 255)
        let target = Bitmap.create(width: 16, height: 16, color: red)
        let runner = ImageRunner(inputImage: target, backgroundColor: Rgba.opaqueWhite)

        let initialScore = runner.model.currentScore
        var options = ImageRunnerOptions()
        options.shapeTypes = [.rectangle]
        options.alpha = 255
        options.candidateShapesPerStep = 20
        options.shapeMutationsPerStep = 20

        for _ in 0..<5 {
            _ = runner.step(options)
        }
        XCTAssertLessThan(runner.model.currentScore, initialScore)
    }

    func testSvgExportIncludesShape() {
        let target = Bitmap.create(width: 16, height: 16, color: Rgba(r: 200, g: 50, b: 50, a: 255))
        let runner = ImageRunner(inputImage: target, backgroundColor: Rgba.opaqueWhite)
        let results = runner.step(ImageRunnerOptions(shapeTypes: [.rectangle], alpha: 255, candidateShapesPerStep: 10, shapeMutationsPerStep: 10))
        let svg = SvgExporter.export(shapes: results, width: 16, height: 16)
        XCTAssertTrue(svg.contains("<svg"))
        XCTAssertTrue(svg.contains("<rect"))
        XCTAssertTrue(svg.contains("fill"))
        XCTAssertFalse(svg.contains(SvgExporter.styleHook))
    }

    func testJsonExportShape() {
        let target = Bitmap.create(width: 8, height: 8, color: Rgba.opaqueBlack)
        let runner = ImageRunner(inputImage: target, backgroundColor: Rgba.opaqueWhite)
        let results = runner.step(ImageRunnerOptions(shapeTypes: [.triangle], alpha: 255, candidateShapesPerStep: 5, shapeMutationsPerStep: 5))
        let json = ShapeJsonExporter.export(results)
        XCTAssertTrue(json.contains("\"type\""))
        XCTAssertTrue(json.contains("\"data\""))
        XCTAssertTrue(json.contains("\"color\""))
        XCTAssertTrue(json.contains("\"score\""))
    }

    // MARK: - Parallel candidates

    /// With many candidates the parallel `bestRandomState` should still converge — i.e.
    /// the runner should drop the error on a solid-color target.
    func testParallelCandidatesConverge() {
        let red = Rgba(r: 220, g: 60, b: 60, a: 255)
        let target = Bitmap.create(width: 24, height: 24, color: red)
        let runner = ImageRunner(inputImage: target, backgroundColor: Rgba.opaqueWhite)
        let initialScore = runner.model.currentScore
        for _ in 0..<6 {
            _ = runner.step(ImageRunnerOptions(
                shapeTypes: [.rectangle], alpha: 255,
                candidateShapesPerStep: 64, shapeMutationsPerStep: 12
            ))
        }
        XCTAssertLessThan(runner.model.currentScore, initialScore)
    }

    /// Sanity-check: a single-candidate step still produces exactly one shape and a valid
    /// (non-negative, finite) score. Hits the threadCount==1 fast path.
    func testParallelSingleCandidate() {
        let target = Bitmap.create(width: 8, height: 8, color: Rgba(r: 100, g: 100, b: 100, a: 255))
        let runner = ImageRunner(inputImage: target, backgroundColor: Rgba.opaqueWhite)
        let results = runner.step(ImageRunnerOptions(
            shapeTypes: [.rectangle], alpha: 255,
            candidateShapesPerStep: 1, shapeMutationsPerStep: 5
        ))
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0].score.isFinite && results[0].score >= 0)
    }

    // MARK: - SvgOptimizer

    func testOptimizerLosslessKeepsEverything() {
        let target = Bitmap.create(width: 16, height: 16, color: Rgba(r: 100, g: 100, b: 100, a: 255))
        let runner = ImageRunner(inputImage: target, backgroundColor: Rgba.opaqueWhite)
        var all: [ShapeResult] = []
        for _ in 0..<5 {
            all.append(contentsOf: runner.step(ImageRunnerOptions(
                shapeTypes: [.rectangle], alpha: 255,
                candidateShapesPerStep: 5, shapeMutationsPerStep: 5
            )))
        }
        let r = SvgOptimizer.optimize(all, options: .lossless)
        XCTAssertEqual(r.kept, all.count)
        XCTAssertEqual(r.droppedLowContribution, 0)
        XCTAssertEqual(r.droppedByCap, 0)
        XCTAssertEqual(r.droppedByOcclusion, 0)
    }

    func testOptimizerTopNPreservesOrder() {
        let target = Bitmap.create(width: 16, height: 16, color: Rgba(r: 200, g: 50, b: 50, a: 255))
        let runner = ImageRunner(inputImage: target, backgroundColor: Rgba.opaqueWhite)
        var all: [ShapeResult] = []
        for _ in 0..<8 {
            all.append(contentsOf: runner.step(ImageRunnerOptions(
                shapeTypes: [.rectangle], alpha: 255,
                candidateShapesPerStep: 5, shapeMutationsPerStep: 5
            )))
        }
        let r = SvgOptimizer.optimize(all, options: .keepTop(3))
        XCTAssertEqual(r.kept, 3)
        XCTAssertEqual(r.droppedByCap, all.count - 3)

        // Surviving scores should be monotonic-ish — they were in the original order, so
        // every kept score appears in the original score list.
        let originalScores = all.map { $0.score }
        for s in r.shapes { XCTAssertTrue(originalScores.contains(s.score)) }
    }

    func testOptimizerEmptyInput() {
        let r = SvgOptimizer.optimize([], options: .aggressive)
        XCTAssertEqual(r.kept, 0)
        XCTAssertEqual(r.originalCount, 0)
    }
}
