# Changelog

## 0.2.0 — 2026-05-15

### Library

- **Parallel candidate evaluation.** `Core.bestRandomState` now distributes the N
  candidate shapes across `DispatchQueue.concurrentPerform` workers, each with its
  own clone of the scratch buffer so per-shape writes don't trample each other. The
  winning state is re-bound to the canonical buffer (via the new
  `ShapeState.withBuffer(_:)` helper) before hill-climbing. Falls back to the
  single-threaded path on single-core devices or via `Core.forceSerialCandidates`.
  Measured speedup is modest (~1.05–1.13× on an 11-core Mac at typical
  `candidatesPerStep` values) because the hill-climb stage remains serial and the
  per-step buffer cloning eats a non-trivial portion of the parallel benefit;
  bigger wins likely require pooling thread-local buffers and parallelizing
  hill-climb start points.
- **`SvgOptimizer`.** New post-processing pass that trims invisible / redundant
  shapes from the `[ShapeResult]` stream so SVGs don't balloon at 2000+ shapes.
  Three passes:
  - Low-contribution drop (delta-score threshold)
  - Top-N preservation in original z-order
  - Back-to-front occlusion culling against a coverage mask
  Returns a `Result` with `kept` / `droppedLowContribution` / `droppedByCap` /
  `droppedByOcclusion` counts, suitable for "Optimized −34%, removed 612" style
  UI badges. Presets: `.lossless`, `.mild`, `.aggressive`, `.keepTop(n)`.
- **`GeometrizeBench` executable target.** A small benchmark that compares serial
  vs parallel `bestRandomState` over 10 trials. Run with
  `swift run -c release GeometrizeBench [candidates]`.

### Demo app

Complete redesign:

- **Onboarding** — single hero (AI-generated portrait built from geometric shapes)
  + serif title + black-pill CTA. Pure cream canvas, no decorative noise.
- **Photo gallery** — Photos.app-style 3-column tight square grid, no per-tile
  chrome, system large title, pull-to-refresh, dark-mode safe.
- **Edit screen** — single image-on-top + floating bottom card pattern.
  - **Concentric corner radius** computed from `UIScreen._displayCornerRadius`
    so card corners stay visually parallel to the hardware screen edge.
  - **Card extends to the screen bottom** via
    `ignoresSafeArea(.container, edges: .bottom)` — no dead zone above the home
    indicator, content inside still respects the indicator height.
  - **Bouncy spring** (`response 0.5, dampingFraction 0.68`) drives the height
    morph and the inner top-half slide-in / slide-out.
  - **Three plain icon tabs** replace the previous capsule strip — `Style` /
    `Shapes` / `Advanced`, active is primary, inactive is quaternary.
  - **Multi-pill status row** — progress (N / M), similarity ((1−score)·100%),
    style label.
  - **Step count slider lives in Style tab** (always one tap away, no longer
    hidden behind Manual override).
  - **Full-screen BorderBeam** at the hardware display radius while drawing.
  - Tap image to start, long-press to peek at the original after a run.

Authored by Suko Kuo ([@kuosuko](https://github.com/kuosuko)).

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
