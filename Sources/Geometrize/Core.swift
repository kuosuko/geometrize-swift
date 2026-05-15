//  Core.swift
//  Geometrize Swift port
//
//  Swift translation by Suko Kuo (@kuosuko), 2026.
//  Original Haxe implementation © 2021 Sam Twidale and contributors
//  (https://github.com/Tw1ddle/geometrize-haxe).
//  Algorithm originates in Michael Fogleman's `primitive` (MIT, 2016).
//
//  MIT License — see LICENSE in the repository root.

import Foundation

/// Core algorithm primitives: color fitting, error metrics, and hill-climbing search.
public enum Core {
    /// When `true`, `bestRandomState` falls back to the serial implementation regardless
    /// of core count. Exposed for benchmarking and A/B comparisons; leave `false` in
    /// production.
    public static var forceSerialCandidates: Bool = false

    /// Calculates the optimal flat color for the area covered by the scanlines, given a target alpha.
    public static func computeColor(target: Bitmap, current: Bitmap, lines: [Scanline], alpha: Int) -> Rgba {
        precondition(alpha >= 0)
        guard alpha > 0 else { return Rgba.transparent }

        var totalRed = 0
        var totalGreen = 0
        var totalBlue = 0
        var count = 0

        let f: Double = 257.0 * 255.0 / Double(alpha)
        let a = Int(f)
        let width = target.width

        target.withUnsafePixels { tgt in
            current.withUnsafePixels { cur in
                guard let tBase = tgt.baseAddress, let cBase = cur.baseAddress else { return }
                for line in lines {
                    let row = line.y * width
                    let tRow = tBase + row
                    let cRow = cBase + row
                    var x = line.x1
                    let xEnd = line.x2
                    while x <= xEnd {
                        let t = tRow[x].value
                        let c = cRow[x].value
                        let tr = Int((t >> 24) & 0xFF)
                        let tg = Int((t >> 16) & 0xFF)
                        let tb = Int((t >> 8) & 0xFF)
                        let cr = Int((c >> 24) & 0xFF)
                        let cg = Int((c >> 16) & 0xFF)
                        let cb = Int((c >> 8) & 0xFF)

                        totalRed   += (tr - cr) * a + cr * 257
                        totalGreen += (tg - cg) * a + cg * 257
                        totalBlue  += (tb - cb) * a + cb * 257
                        count += 1
                        x += 1
                    }
                }
            }
        }

        if count == 0 { return Rgba(value: 0) }

        let r = Util.clamp((totalRed / count) >> 8, 0, 255)
        let g = Util.clamp((totalGreen / count) >> 8, 0, 255)
        let b = Util.clamp((totalBlue / count) >> 8, 0, 255)
        return Rgba(r: r, g: g, b: b, a: alpha)
    }

    /// Root-mean-square error between two same-sized bitmaps, normalized to [0, 1].
    public static func differenceFull(first: Bitmap, second: Bitmap) -> Double {
        precondition(first.width == second.width && first.height == second.height)
        precondition(first.width != 0 && first.height != 0)

        var total: Int64 = 0
        let count = first.width * first.height

        first.withUnsafePixels { a in
            second.withUnsafePixels { b in
                guard let pa = a.baseAddress, let pb = b.baseAddress else { return }
                var i = 0
                while i < count {
                    let av = pa[i].value
                    let bv = pb[i].value
                    let dr = Int((av >> 24) & 0xFF) - Int((bv >> 24) & 0xFF)
                    let dg = Int((av >> 16) & 0xFF) - Int((bv >> 16) & 0xFF)
                    let db = Int((av >>  8) & 0xFF) - Int((bv >>  8) & 0xFF)
                    let da = Int( av        & 0xFF) - Int( bv        & 0xFF)
                    total &+= Int64(dr * dr + dg * dg + db * db + da * da)
                    i += 1
                }
            }
        }

        let denom = Double(count) * 4.0
        let result = (total <= 0) ? 0.0 : sqrt(Double(total) / denom) / 255.0
        precondition(result.isFinite)
        return result
    }

    /// Incrementally updates the RMS error for only the pixels covered by the scanlines.
    public static func differencePartial(
        target: Bitmap, before: Bitmap, after: Bitmap, score: Double, lines: [Scanline]
    ) -> Double {
        precondition(!lines.isEmpty)
        let width = target.width
        let height = target.height
        let rgbaCount = width * height * 4
        var total: Double = pow(score * 255.0, 2) * Double(rgbaCount)

        target.withUnsafePixels { tgt in
            before.withUnsafePixels { bef in
                after.withUnsafePixels { aft in
                    guard let pt = tgt.baseAddress, let pb = bef.baseAddress, let pa = aft.baseAddress else { return }
                    for line in lines {
                        let row = line.y * width
                        var x = line.x1
                        let xEnd = line.x2
                        while x <= xEnd {
                            let tv = pt[row + x].value
                            let bv = pb[row + x].value
                            let av = pa[row + x].value

                            let tr = Int((tv >> 24) & 0xFF)
                            let tg = Int((tv >> 16) & 0xFF)
                            let tb = Int((tv >>  8) & 0xFF)
                            let ta = Int( tv        & 0xFF)

                            let dtbr = tr - Int((bv >> 24) & 0xFF)
                            let dtbg = tg - Int((bv >> 16) & 0xFF)
                            let dtbb = tb - Int((bv >>  8) & 0xFF)
                            let dtba = ta - Int( bv        & 0xFF)

                            let dtar = tr - Int((av >> 24) & 0xFF)
                            let dtag = tg - Int((av >> 16) & 0xFF)
                            let dtab = tb - Int((av >>  8) & 0xFF)
                            let dtaa = ta - Int( av        & 0xFF)

                            total -= Double(dtbr * dtbr + dtbg * dtbg + dtbb * dtbb + dtba * dtba)
                            total += Double(dtar * dtar + dtag * dtag + dtab * dtab + dtaa * dtaa)
                            x += 1
                        }
                    }
                }
            }
        }
        let safe = max(total, 0)
        let result = sqrt(safe / Double(rgbaCount)) / 255.0
        precondition(result.isFinite)
        return result
    }

    /// Picks the lowest-energy of `n` randomly generated states.
    ///
    /// Candidates are evaluated in parallel via `DispatchQueue.concurrentPerform`. Each
    /// worker gets its own clone of the buffer bitmap so per-shape scratch writes don't
    /// trample each other. The winning state is re-bound to the canonical `buffer`
    /// before being returned, so subsequent hill-climbing uses the model's buffer.
    public static func bestRandomState(
        shapes: [ShapeType], alpha: Int, n: Int,
        target: Bitmap, current: Bitmap, buffer: Bitmap, lastScore: Double
    ) -> ShapeState {
        precondition(n > 0)
        let cores = max(1, min(ProcessInfo.processInfo.activeProcessorCount, 8))
        let threadCount = max(1, min(cores, n))

        if threadCount == 1 || forceSerialCandidates {
            return bestRandomStateSerial(
                shapes: shapes, alpha: alpha, n: n,
                target: target, current: current, buffer: buffer, lastScore: lastScore
            )
        }

        // One scratch buffer per worker.
        let buffers: [Bitmap] = (0..<threadCount).map { _ in buffer.clone() }
        var bestStates: [ShapeState?] = Array(repeating: nil, count: threadCount)
        var bestEnergies: [Double] = Array(repeating: .infinity, count: threadCount)
        let xBound = current.width
        let yBound = current.height

        bestStates.withUnsafeMutableBufferPointer { statesPtr in
            bestEnergies.withUnsafeMutableBufferPointer { energiesPtr in
                DispatchQueue.concurrentPerform(iterations: threadCount) { ti in
                    let startIdx = (n * ti) / threadCount
                    let endIdx = (n * (ti + 1)) / threadCount
                    let threadBuffer = buffers[ti]

                    var localBestEnergy: Double = .infinity
                    var localBestState: ShapeState?

                    for _ in startIdx..<endIdx {
                        let state = ShapeState(
                            shape: ShapeFactory.randomShape(of: shapes, xBound: xBound, yBound: yBound),
                            alpha: alpha,
                            target: target, current: current, buffer: threadBuffer
                        )
                        let energy = state.energy(lastScore: lastScore)
                        if energy < localBestEnergy {
                            localBestEnergy = energy
                            localBestState = state
                        }
                    }
                    statesPtr[ti] = localBestState
                    energiesPtr[ti] = localBestEnergy
                }
            }
        }

        var bestIdx = 0
        var bestEnergy = bestEnergies[0]
        for i in 1..<threadCount {
            if bestStates[i] != nil, bestEnergies[i] < bestEnergy {
                bestEnergy = bestEnergies[i]
                bestIdx = i
            }
        }
        let winner = bestStates[bestIdx]!
        return winner.withBuffer(buffer)
    }

    /// Single-threaded variant — used as the fast path for small candidate counts and
    /// as a fallback on single-core devices.
    private static func bestRandomStateSerial(
        shapes: [ShapeType], alpha: Int, n: Int,
        target: Bitmap, current: Bitmap, buffer: Bitmap, lastScore: Double
    ) -> ShapeState {
        var bestEnergy: Double = 0
        var bestState: ShapeState?

        for i in 0..<n {
            let state = ShapeState(
                shape: ShapeFactory.randomShape(of: shapes, xBound: current.width, yBound: current.height),
                alpha: alpha,
                target: target, current: current, buffer: buffer
            )
            let energy = state.energy(lastScore: lastScore)
            if i == 0 || energy < bestEnergy {
                bestEnergy = energy
                bestState = state
            }
        }
        return bestState!
    }

    /// Combines random sampling with hill-climbing to find a low-energy state.
    public static func bestHillClimbState(
        shapes: [ShapeType], alpha: Int, n: Int, age: Int,
        target: Bitmap, current: Bitmap, buffer: Bitmap, lastScore: Double
    ) -> ShapeState {
        let state = bestRandomState(shapes: shapes, alpha: alpha, n: n, target: target, current: current, buffer: buffer, lastScore: lastScore)
        return hillClimb(state: state, maxAge: age, lastScore: lastScore)
    }

    /// Hill-climbing optimizer: mutates the state, accepts improvements, reverts regressions.
    public static func hillClimb(state initial: ShapeState, maxAge: Int, lastScore: Double) -> ShapeState {
        precondition(maxAge >= 0)
        var state = initial.clone()
        var bestState = state.clone()
        var bestEnergy = state.energy(lastScore: lastScore)

        var age = 0
        while age < maxAge {
            let undo = state.mutate()
            let energy = state.energy(lastScore: lastScore)
            if energy >= bestEnergy {
                state = undo
            } else {
                bestEnergy = energy
                bestState = state.clone()
                age = -1
            }
            age += 1
        }
        return bestState
    }

    /// Energy of adding `shape` with the given alpha to the current image — lower is better.
    public static func energy(
        shape: any Shape, alpha: Int,
        target: Bitmap, current: Bitmap, buffer: Bitmap, score: Double
    ) -> Double {
        let lines = shape.rasterize()
        precondition(!lines.isEmpty, "Shape rasterized to zero scanlines")

        let color = computeColor(target: target, current: current, lines: lines, alpha: alpha)
        Rasterizer.copyLines(destination: buffer, source: current, lines: lines)
        Rasterizer.drawLines(image: buffer, color: color, lines: lines)
        return differencePartial(target: target, before: current, after: buffer, score: score, lines: lines)
    }
}
