# Changelog

## 0.1.0 — 2026-05-15

Initial release. Swift port of [geometrize-haxe](https://github.com/Tw1ddle/geometrize-haxe).

### Library (`Geometrize`)

- All 8 shape primitives from upstream (rectangle, rotated rectangle, triangle, ellipse, rotated ellipse, circle, line, quadratic Bézier).
- `ImageRunner` + `ImageRunnerOptions` high-level API.
- `Model`, `Core` (hill-climb + RMS error), `ShapeState`, `Shape`, `ShapeFactory`.
- `SvgExporter` and `ShapeJsonExporter` matching upstream output format.
- `Bitmap` with reference semantics, `CGImage` bridge with sRGB un-premultiplication.
- `Util.averageColor()` extension for sensible background defaults.

### Performance

- SplitMix64 thread-local PRNG (replaces `Int.random(in:)`'s crypto-grade RNG on the hot path).
- Unsafe-buffer pixel access in `Rasterizer.drawLines` / `copyLines` and `Core.computeColor` / `differenceFull` / `differencePartial`.
- 256-entry fixed-point reciprocal table for CGImage un-premultiplication.
- `scanlinesForPolygon` rewritten as a single-pass min/max instead of `Set` + sort.

### Demo app (`GeometrizeDemo`, iOS 17+)

- SwiftUI app with target/result split panes, live stats (shape count, RMS error, run state).
- 5 named parameter presets (Fast preview, Balanced, High quality, Stained glass, Linework).
- Shape primitive toggles with SF Symbols.
- Six sliders (alpha, candidates per step, mutations per candidate, max bitmap dimension, shapes per UI refresh, total shape limit) with inline help text.
- Background mode picker (average / white / black / custom color).
- SVG / JSON share-sheet export.
- "Load sample image" generator for trying it without a Photos library.

### Tests

10 XCTest cases covering Rgba round-trip + clamping, Bitmap create/clone/getBytes, Scanline trim, every `ShapeType` instantiates, optimizer drops error on a solid-color target, SVG and JSON exports contain expected attributes.
