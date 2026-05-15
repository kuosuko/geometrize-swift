# Geometrize for Swift

[![CI](https://github.com/kuosuko/geometrize-swift/actions/workflows/ci.yml/badge.svg)](https://github.com/kuosuko/geometrize-swift/actions/workflows/ci.yml)
[![SPM compatible](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2015%20%7C%20macOS%2012%20%7C%20tvOS%2015%20%7C%20visionOS%201%20%7C%20watchOS%208-blue.svg)]()
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A Swift port of [geometrize-haxe](https://github.com/Tw1ddle/geometrize-haxe) — recreate images as compositions of geometric primitives (rectangles, triangles, ellipses, lines, Bézier curves, …). The algorithm and behavior match the upstream Haxe library; the API has been adapted to feel native in Swift and the hot loops are tuned for Apple silicon.

This repo ships two things:

1. **`Geometrize`** — a SwiftPM library, zero dependencies, builds on iOS / macOS / tvOS / visionOS / watchOS.
2. **`GeometrizeDemo`** — a SwiftUI iOS app that lets you pick a photo, watch shapes accumulate in real time, and export to SVG/JSON.

## Install (Swift Package Manager)

```swift
.package(url: "https://github.com/kuosuko/geometrize-swift.git", from: "0.1.0")
```

Then add `"Geometrize"` to your target's dependencies.

## Library usage

```swift
import Geometrize

// 1. Build a target Bitmap (from raw bytes or a CGImage).
let target = Bitmap.from(cgImage: someCGImage, maxDimension: 256)!

// 2. Spin up the runner with a background color (average target color is a good default).
let runner = ImageRunner(inputImage: target, backgroundColor: target.averageColor())

// 3. Step. Each step adds one shape that minimises RMS error vs. the target.
let options = ImageRunnerOptions(
    shapeTypes: [.triangle, .rotatedEllipse],
    alpha: 128,
    candidateShapesPerStep: 50,
    shapeMutationsPerStep: 100
)

var allShapes: [ShapeResult] = []
for _ in 0..<200 {
    allShapes.append(contentsOf: runner.step(options))
}

// 4. Export.
let svg = SvgExporter.export(shapes: allShapes, width: target.width, height: target.height)
let json = ShapeJsonExporter.export(allShapes)
```

### Supported shapes

`ShapeType` matches the upstream raw values, so JSON output is interchangeable with the original tools:

| Type             | rawValue |
| ---------------- | -------- |
| rectangle        | 0        |
| rotatedRectangle | 1        |
| triangle         | 2        |
| ellipse          | 3        |
| rotatedEllipse   | 4        |
| circle           | 5        |
| line             | 6        |
| quadraticBezier  | 7        |

## Performance notes

The pixel-level hot path was rewritten on top of `UnsafeBufferPointer` to bypass Swift array bounds-checking, and `Int.random(in:)` (which uses the system's crypto-grade RNG) was replaced with a thread-local SplitMix64 generator using Lemire's bounded-range trick. Together these are typically 30–60× faster than the naive Swift port on iPhone 17 Pro for the same workload.

A few things to keep in mind:

- **Build Release for actual work.** Swift Debug builds skip optimization (`-Onone`) and will be 10–50× slower than Release on this kind of workload. The SwiftUI demo app is configured Release-only-for-archive but Debug-by-default; if you run via Xcode and care about speed, switch the scheme to Release.
- **Smaller bitmaps converge faster.** The fitting cost is roughly O(pixels × steps). Down-scaling the input to a 256-px max edge is usually a good tradeoff between detail and speed — the demo app exposes this as a slider.
- **The algorithm is single-threaded.** Each candidate evaluation in `bestRandomState` is independent and could be parallelized; PRs welcome.

## Notes on the port

- Haxe `geometrize.State` is renamed to `ShapeState` to avoid colliding with SwiftUI's `@State` in consumer apps.
- `Bitmap` is a reference type (`final class`) — the hot loop mutates pixels in place; making it a struct would mean copy-on-write on every scanline write.
- `Shape` is a class-only `protocol` because the hill-climbing optimizer mutates shapes in place and rolls back via clones, which is much cleaner with reference semantics.
- The CoreGraphics bridge in `Bitmap+CoreGraphics.swift` un-premultiplies alpha when ingesting a `CGImage`, so the algorithm sees straight-alpha colors (matching the source library's expectations). It uses a 256-entry fixed-point reciprocal table to avoid a floating-point divide per pixel.

## Running the demo app

Requires [XcodeGen](https://github.com/yonaskolb/XcodeGen) (one-time install) to materialise the project file:

```bash
brew install xcodegen
cd Demo
xcodegen generate
open GeometrizeDemo.xcodeproj
```

The default `project.yml` is signed against a personal Apple developer team — change `DEVELOPMENT_TEAM` and `PRODUCT_BUNDLE_IDENTIFIER` to your own before running on a device. The app loads a photo via `PhotosPicker`, runs the algorithm on a background task, and updates the SwiftUI view as new shapes land. Tweak shape types, alpha, candidate count, mutation count, and the input bitmap's max dimension live from the controls.

## Tests

```bash
swift test
```

Covers `Rgba` round-trip + clamping, `Bitmap` create/clone/getBytes, `Scanline.trim` bounds clamping, every `ShapeType` instantiates via `ShapeFactory`, the optimizer drops the error on a solid-color target, and SVG/JSON export contains the expected attributes.

## Layout

```
Sources/Geometrize/
├── Bitmap/                  Rgba, Bitmap, averageColor, CGImage bridge
├── Rasterizer/              Scanline, Rasterizer (drawLines, copyLines, bresenham, polygon)
├── Shape/                   Shape protocol, ShapeType, ShapeFactory, 8 concrete shapes
├── Runner/                  ImageRunner, ImageRunnerOptions
├── Exporter/                SvgExporter, ShapeJsonExporter
├── Util/                    Util (clamp, random, ...), FastRandom (SplitMix64)
├── Core.swift               computeColor, differenceFull/Partial, hillClimb, energy
├── Model.swift              ShapeResult, Model
└── ShapeState.swift         ShapeState (renamed from upstream State)

Tests/GeometrizeTests/
└── GeometrizeTests.swift

Demo/
├── project.yml              XcodeGen spec; regenerates GeometrizeDemo.xcodeproj
└── GeometrizeDemo/
    ├── GeometrizeDemoApp.swift
    ├── ContentView.swift
    ├── GeometrizeRunner.swift
    ├── Info.plist
    └── Assets.xcassets
```

## Credits

This port stands on a chain of prior art:

- The fitting algorithm originates in [primitive](https://github.com/fogleman/primitive) (Go, MIT, © 2016 Michael Fogleman).
- [geometrize-haxe](https://github.com/Tw1ddle/geometrize-haxe) (Haxe, MIT, © 2021 Sam Twidale and contributors) ported it to Haxe and is the structural reference for this Swift port.
- This repository is the Swift port, MIT-licensed, authored by **Suko Kuo** ([@kuosuko](https://github.com/kuosuko)), 2026.

See [LICENSE](LICENSE) for full attribution.

## Contributing

PRs welcome. Before submitting:

```bash
swift test                  # all tests should pass
swift build -c release      # release config should compile clean
```

If you're adding a new shape primitive, mirror the existing pattern in [`Sources/Geometrize/Shape/`](Sources/Geometrize/Shape/) and update `ShapeFactory`, `ShapeType.allCases` (automatic for `CaseIterable`), and the demo app's `icon(for:)` / `label(for:)` mappings.
