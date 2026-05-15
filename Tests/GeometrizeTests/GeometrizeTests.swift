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
}
