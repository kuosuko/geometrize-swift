//  GeometrizeBench — serial vs parallel candidate evaluation timing.
//  Run with: `swift run -c release GeometrizeBench`

import Foundation
import Geometrize

// MARK: - Test image generator

/// Generates a deterministic 200×200 RGBA bitmap with smooth gradients + a couple of
/// circular blobs, so the fitting workload has structure to learn from.
func makeTestBitmap(seed: UInt64) -> Bitmap {
    let w = 200, h = 200
    var bytes = [UInt8](repeating: 0, count: w * h * 4)

    // Simple LCG for deterministic content per seed.
    var s = seed == 0 ? 0xDEADBEEF : seed
    @inline(__always) func nextByte() -> UInt8 {
        s = s &* 6364136223846793005 &+ 1442695040888963407
        return UInt8(truncatingIfNeeded: s >> 56)
    }

    for y in 0..<h {
        for x in 0..<w {
            let i = (y * w + x) * 4
            let gx = Double(x) / Double(w - 1)
            let gy = Double(y) / Double(h - 1)
            // Diagonal gradient + a circular blob at (0.7, 0.3).
            let dx = gx - 0.7
            let dy = gy - 0.3
            let blob = exp(-(dx * dx + dy * dy) * 18)
            let r = min(255, max(0, Int(255 * (0.2 + 0.5 * gx + 0.4 * blob))))
            let g = min(255, max(0, Int(255 * (0.3 + 0.4 * gy + 0.2 * blob))))
            let b = min(255, max(0, Int(255 * (0.5 - 0.3 * gx + 0.6 * (1 - blob)))))
            bytes[i]     = UInt8(r) &+ (nextByte() & 0x07) &- 4 // tiny noise
            bytes[i + 1] = UInt8(g) &+ (nextByte() & 0x07) &- 4
            bytes[i + 2] = UInt8(b) &+ (nextByte() & 0x07) &- 4
            bytes[i + 3] = 255
        }
    }
    return Bitmap.create(width: w, height: h, bytes: bytes)
}

// MARK: - Timing helpers

func stats(_ xs: [Double]) -> (min: Double, max: Double, mean: Double, median: Double) {
    let sorted = xs.sorted()
    let mean = xs.reduce(0, +) / Double(xs.count)
    let median: Double = {
        let n = sorted.count
        if n.isMultiple(of: 2) {
            return (sorted[n / 2 - 1] + sorted[n / 2]) / 2
        }
        return sorted[n / 2]
    }()
    return (sorted.first!, sorted.last!, mean, median)
}

func runTrial(serial: Bool, stepsPerTrial: Int, options: ImageRunnerOptions) -> Double {
    Core.forceSerialCandidates = serial
    let target = makeTestBitmap(seed: 42)
    let runner = ImageRunner(inputImage: target, backgroundColor: target.averageColor())
    let start = Date()
    for _ in 0..<stepsPerTrial {
        _ = runner.step(options)
    }
    return Date().timeIntervalSince(start)
}

func fmt(_ s: Double) -> String {
    String(format: "%6.3fs", s)
}

// MARK: - Main

let trials = 10
let stepsPerTrial = 10
let options = ImageRunnerOptions(
    shapeTypes: [.triangle, .rotatedEllipse],
    alpha: 128,
    candidateShapesPerStep: CommandLine.arguments.dropFirst().first.flatMap(Int.init) ?? 100,
    shapeMutationsPerStep: 100
)

print("Geometrize bench — parallel vs serial bestRandomState")
print("Host: \(Host.current().localizedName ?? "?")  cores=\(ProcessInfo.processInfo.activeProcessorCount)")
print("Image 200×200, candidates/step=\(options.candidateShapesPerStep), mutations=\(options.shapeMutationsPerStep), shapes=\(options.shapeTypes)")
print("Trials=\(trials), steps/trial=\(stepsPerTrial)")
print()

// Warmup — JIT, caches, page faults, etc.
print("warming up…", terminator: " ")
fflush(stdout)
_ = runTrial(serial: false, stepsPerTrial: 5, options: options)
_ = runTrial(serial: true,  stepsPerTrial: 5, options: options)
print("done.\n")

// Serial
print("--- serial ---")
var serialTimes: [Double] = []
for t in 1...trials {
    let elapsed = runTrial(serial: true, stepsPerTrial: stepsPerTrial, options: options)
    serialTimes.append(elapsed)
    print("trial \(String(format: "%2d", t)): \(fmt(elapsed))")
}

// Parallel
print()
print("--- parallel ---")
var parallelTimes: [Double] = []
for t in 1...trials {
    let elapsed = runTrial(serial: false, stepsPerTrial: stepsPerTrial, options: options)
    parallelTimes.append(elapsed)
    print("trial \(String(format: "%2d", t)): \(fmt(elapsed))")
}

// Summary
let s = stats(serialTimes)
let p = stats(parallelTimes)
let speedupMean = s.mean / p.mean
let speedupMedian = s.median / p.median

print()
print("--- summary (\(stepsPerTrial) steps per trial) ---")
print("                min      median   mean     max")
print("  serial    \(fmt(s.min))  \(fmt(s.median))  \(fmt(s.mean))  \(fmt(s.max))")
print("  parallel  \(fmt(p.min))  \(fmt(p.median))  \(fmt(p.mean))  \(fmt(p.max))")
print()
print(String(format: "  speedup (median): %.2fx", speedupMedian))
print(String(format: "  speedup (mean):   %.2fx", speedupMean))

// Per-step throughput
let serialPerStep = s.median / Double(stepsPerTrial)
let parallelPerStep = p.median / Double(stepsPerTrial)
print()
print(String(format: "  per-step median:  serial %.3fs   parallel %.3fs", serialPerStep, parallelPerStep))
