//  ShapeState.swift
//  Geometrize Swift port — equivalent of upstream `geometrize.State`.
//  Renamed in the Swift port to avoid colliding with SwiftUI's `@State`.
//
//  Swift translation + `withBuffer(_:)` helper for parallel candidate evaluation
//  by Suko Kuo (@kuosuko), 2026. MIT.

import Foundation

/// A candidate state in the optimization search — a shape plus its evaluation context.
public final class ShapeState {
    public let shape: any Shape
    public let alpha: Int
    /// Cached energy score. Negative means "needs recalculation".
    public var score: Double

    @usableFromInline let target: Bitmap
    @usableFromInline let current: Bitmap
    @usableFromInline let buffer: Bitmap

    public init(shape: any Shape, alpha: Int, target: Bitmap, current: Bitmap, buffer: Bitmap) {
        self.shape = shape
        self.alpha = alpha
        self.score = -1
        self.target = target
        self.current = current
        self.buffer = buffer
    }

    /// Cached energy measure. Reset `score` to a negative value to force recomputation.
    public func energy(lastScore: Double) -> Double {
        if score < 0 {
            score = Core.energy(shape: shape, alpha: alpha, target: target, current: current, buffer: buffer, score: lastScore)
        }
        return score
    }

    /// Mutates the shape in place and returns the previous state (for rollback).
    @discardableResult
    public func mutate() -> ShapeState {
        let old = clone()
        shape.mutate()
        score = -1
        return old
    }

    /// Deep-copies the shape; bitmap references are shared. Score is not preserved.
    public func clone() -> ShapeState {
        ShapeState(shape: shape.clone(), alpha: alpha, target: target, current: current, buffer: buffer)
    }

    /// Returns a new state bound to a different buffer bitmap. Used when migrating a
    /// candidate evaluated against a per-thread scratch buffer onto the canonical buffer
    /// that subsequent stages (hill climb, model add) will use. The cached score is reset.
    func withBuffer(_ newBuffer: Bitmap) -> ShapeState {
        let copy = ShapeState(shape: shape, alpha: alpha, target: target, current: current, buffer: newBuffer)
        copy.score = -1
        return copy
    }
}
