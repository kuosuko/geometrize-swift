//  FastRandom.swift
//  Geometrize Swift port — new addition to the lineage.
//
//  Replaces `Int.random(in:)` (crypto-grade) on the hot path with a thread-local
//  SplitMix64 generator plus Lemire's nearly-divisionless bounded random.
//  Author: Suko Kuo (@kuosuko), 2026. MIT.

import Foundation

/// A fast non-cryptographic PRNG (SplitMix64).
///
/// `Int.random(in:)` uses `SystemRandomNumberGenerator`, which delegates to `getentropy`/`SecRandomCopyBytes`.
/// That's overkill for the millions of random integers Geometrize draws during a single fit,
/// and benchmarks show it dominates step time on iOS. SplitMix64 is small, branchless,
/// and good enough for stochastic search.
@usableFromInline
struct FastRandom: RandomNumberGenerator {
    @usableFromInline var state: UInt64

    @inlinable
    init(seed: UInt64) {
        // Seed must never be zero; if caller hands us zero, salt it.
        self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    @inlinable
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// Thread-local PRNG. Each thread gets its own SplitMix64 seeded from a time-based unique value.
enum ThreadRandom {
    @usableFromInline
    static let key: pthread_key_t = {
        var k = pthread_key_t()
        pthread_key_create(&k) { ptr in
            ptr.deallocate()
        }
        return k
    }()

    @inlinable
    static func get() -> UnsafeMutablePointer<FastRandom> {
        if let raw = pthread_getspecific(key) {
            return raw.assumingMemoryBound(to: FastRandom.self)
        }
        let ptr = UnsafeMutablePointer<FastRandom>.allocate(capacity: 1)
        // Mix the thread id, a high-resolution timestamp, and the pointer address for the seed.
        var tid: UInt64 = 0
        pthread_threadid_np(nil, &tid)
        let now = mach_absolute_time()
        let addr = UInt64(UInt(bitPattern: ptr))
        ptr.initialize(to: FastRandom(seed: tid &* 0xD1342543DE82EF95 &+ now &+ addr))
        pthread_setspecific(key, UnsafeRawPointer(ptr))
        return ptr
    }
}

/// Returns a fast random integer in `[0, upper)`. Uses Lemire's nearly-divisionless bounded random.
@usableFromInline
func fastRandom(below upper: Int) -> Int {
    precondition(upper > 0)
    let ptr = ThreadRandom.get()
    let range = UInt64(upper)
    var x = ptr.pointee.next()
    var m = x.multipliedFullWidth(by: range)
    if m.low < range {
        let t = (0 &- range) % range
        while m.low < t {
            x = ptr.pointee.next()
            m = x.multipliedFullWidth(by: range)
        }
    }
    return Int(m.high)
}

/// Returns a fast random integer in `[lower, upper]` (inclusive both ends).
@usableFromInline
func fastRandom(_ lower: Int, _ upper: Int) -> Int {
    precondition(lower <= upper)
    return lower + fastRandom(below: upper - lower + 1)
}
