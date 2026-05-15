//  SvgOptimizer.swift
//  Geometrize Swift port — new addition to the lineage (no upstream Haxe equivalent).
//
//  Trims a `[ShapeResult]` stream so SVGs don't balloon at 2000+ shapes.
//  Three passes: low-contribution drop, top-N selection, occlusion culling.
//
//  Author: Suko Kuo (@kuosuko), 2026. MIT.

import Foundation

/// Post-processes a sequence of `ShapeResult`s to produce smaller, cleaner SVGs.
///
/// The geometrize algorithm accumulates hundreds-to-thousands of overlapping shapes.
/// The raw stream is faithful to the algorithm's output but it contains a lot of
/// shapes that contribute almost nothing visually because later shapes paint over them.
/// This optimizer applies a few cheap passes to trim that fat:
///
/// - **Low-contribution drop.** Each shape's contribution is roughly the score improvement
///   it produced when it was added (`previousScore - thisScore`). Shapes below
///   `minContribution` are removed.
/// - **Top-N selection.** Optionally keep only the N highest-contribution shapes,
///   preserving their original z-order so layering still reads correctly.
/// - **Occlusion culling.** Walks the list back-to-front maintaining a coverage mask;
///   shapes whose scanlines are fully covered by later near-opaque shapes are dropped.
///   Costs O(pixels × shapes) and is only meaningful when late shapes have high alpha.
///
/// Pure value-level transform — does not touch the bitmap, does not re-fit, does not
/// introduce new shapes. Original ordering is preserved within the surviving set.
///
/// Authored by Suko Kuo (@kuosuko) as part of the Swift port.
public enum SvgOptimizer {
    public struct Options: Sendable {
        /// Drop shapes whose individual contribution to the score (`prevScore - thisScore`)
        /// is at or below this value. Score is normalized `[0, 1]`, so practical values are tiny.
        /// `0` keeps everything; `1e-5` is a safe starting point for "trim invisibles".
        public var minContribution: Double
        /// If set, keep at most this many shapes — the highest-contribution ones, in original order.
        public var maxShapes: Int?
        /// If `true`, drop shapes whose pixels are fully covered by later opaque/near-opaque shapes.
        public var occlusionCulling: Bool
        /// When `occlusionCulling` is enabled, treat any shape with alpha `>= occlusionAlphaThreshold`
        /// as fully covering its scanlines (so the shape behind it can be discarded).
        public var occlusionAlphaThreshold: Int

        public init(
            minContribution: Double = 0,
            maxShapes: Int? = nil,
            occlusionCulling: Bool = false,
            occlusionAlphaThreshold: Int = 245
        ) {
            self.minContribution = minContribution
            self.maxShapes = maxShapes
            self.occlusionCulling = occlusionCulling
            self.occlusionAlphaThreshold = occlusionAlphaThreshold
        }

        /// Named presets for common goals.
        public static let lossless = Options()
        public static let mild = Options(minContribution: 1e-5)
        public static let aggressive = Options(minContribution: 5e-5, occlusionCulling: true)
        public static func keepTop(_ n: Int) -> Options { Options(maxShapes: n) }
    }

    /// Summary of what the optimizer did. Useful for displaying a "saved X KB · removed N
    /// shapes" stat in the UI.
    public struct Result {
        public let shapes: [ShapeResult]
        public let kept: Int
        public let droppedLowContribution: Int
        public let droppedByCap: Int
        public let droppedByOcclusion: Int
        public var originalCount: Int {
            kept + droppedLowContribution + droppedByCap + droppedByOcclusion
        }
    }

    public static func optimize(_ shapes: [ShapeResult], options: Options) -> Result {
        guard !shapes.isEmpty else {
            return Result(shapes: [], kept: 0, droppedLowContribution: 0, droppedByCap: 0, droppedByOcclusion: 0)
        }

        // Per-shape contribution: how much the score improved when it was placed.
        // First shape's contribution is approximated against a worst-case initial score of 1.0.
        var contributions: [Double] = []
        contributions.reserveCapacity(shapes.count)
        for (i, s) in shapes.enumerated() {
            let prevScore = i == 0 ? 1.0 : shapes[i - 1].score
            contributions.append(max(0, prevScore - s.score))
        }

        var keepMask = [Bool](repeating: true, count: shapes.count)

        // Pass 1 — drop low-contribution shapes.
        var droppedLow = 0
        if options.minContribution > 0 {
            for i in 0..<shapes.count where contributions[i] < options.minContribution {
                keepMask[i] = false
                droppedLow += 1
            }
        }

        // Pass 2 — top-N by contribution, preserving original z-order.
        var droppedCap = 0
        if let cap = options.maxShapes, cap > 0 {
            var surviving = (0..<shapes.count).filter { keepMask[$0] }
            if surviving.count > cap {
                surviving.sort { contributions[$0] > contributions[$1] }
                let kept = Set(surviving.prefix(cap))
                for i in 0..<shapes.count where keepMask[i] && !kept.contains(i) {
                    keepMask[i] = false
                    droppedCap += 1
                }
            }
        }

        // Pass 3 — occlusion culling against a back-to-front coverage mask.
        var droppedOcc = 0
        if options.occlusionCulling {
            let bounds = computeCanvasBounds(shapes: shapes, keepMask: keepMask)
            if bounds.width > 0 && bounds.height > 0 {
                var coverage = [Bool](repeating: false, count: bounds.width * bounds.height)
                let threshold = options.occlusionAlphaThreshold
                for i in (0..<shapes.count).reversed() where keepMask[i] {
                    let lines = shapes[i].shape.rasterize()
                    var totalPixels = 0
                    var coveredPixels = 0
                    for line in lines {
                        let y = line.y
                        if y < 0 || y >= bounds.height { continue }
                        let row = y * bounds.width
                        let xStart = max(0, line.x1)
                        let xEnd = min(bounds.width - 1, line.x2)
                        if xStart > xEnd { continue }
                        for x in xStart...xEnd {
                            totalPixels += 1
                            if coverage[row + x] { coveredPixels += 1 }
                        }
                    }
                    if totalPixels > 0 && coveredPixels == totalPixels {
                        keepMask[i] = false
                        droppedOcc += 1
                        continue
                    }
                    if shapes[i].color.a >= threshold {
                        for line in lines {
                            let y = line.y
                            if y < 0 || y >= bounds.height { continue }
                            let row = y * bounds.width
                            let xStart = max(0, line.x1)
                            let xEnd = min(bounds.width - 1, line.x2)
                            if xStart > xEnd { continue }
                            for x in xStart...xEnd {
                                coverage[row + x] = true
                            }
                        }
                    }
                }
            }
        }

        let kept = zip(shapes, keepMask).compactMap { $1 ? $0 : nil }
        return Result(
            shapes: kept,
            kept: kept.count,
            droppedLowContribution: droppedLow,
            droppedByCap: droppedCap,
            droppedByOcclusion: droppedOcc
        )
    }

    /// Convenience wrapper that just returns the surviving shapes.
    public static func optimized(_ shapes: [ShapeResult], options: Options) -> [ShapeResult] {
        optimize(shapes, options: options).shapes
    }

    private static func computeCanvasBounds(shapes: [ShapeResult], keepMask: [Bool]) -> (width: Int, height: Int) {
        var maxX = 0
        var maxY = 0
        for (i, s) in shapes.enumerated() where keepMask[i] {
            for line in s.shape.rasterize() {
                if line.y + 1 > maxY { maxY = line.y + 1 }
                if line.x2 + 1 > maxX { maxX = line.x2 + 1 }
            }
        }
        return (maxX, maxY)
    }
}
