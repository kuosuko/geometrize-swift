import Foundation

/// Represents a point in 2D integer space.
public struct Point: Equatable, Hashable, Sendable {
    public var x: Int
    public var y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
}

/// Utility functions used throughout the library.
public enum Util {
    /// Clamps a value within an inclusive range.
    @inlinable
    public static func clamp(_ value: Int, _ minValue: Int, _ maxValue: Int) -> Int {
        precondition(minValue <= maxValue)
        if value < minValue { return minValue }
        if value > maxValue { return maxValue }
        return value
    }

    /// Returns a uniformly distributed random integer in the inclusive range `[lower, upper]`.
    public static func random(_ lower: Int, _ upper: Int) -> Int {
        fastRandom(lower, upper)
    }

    /// Returns a uniformly distributed random integer in the range `[0, upper)`.
    /// Mirrors Haxe's `Std.random(upper)`.
    public static func random(below upper: Int) -> Int {
        fastRandom(below: upper)
    }

    /// Picks a random element from a non-empty array.
    public static func randomArrayItem<T>(_ array: [T]) -> T {
        precondition(!array.isEmpty)
        return array[fastRandom(below: array.count)]
    }

    /// Returns the minimum and maximum elements of an array, packed into a Point as (min, max).
    public static func minMaxElements(_ values: [Int]) -> Point {
        guard let first = values.first else { return Point(x: 0, y: 0) }
        var lo = first
        var hi = first
        for v in values {
            if v < lo { lo = v }
            if v > hi { hi = v }
        }
        return Point(x: lo, y: hi)
    }

    /// Converts degrees to radians.
    @inlinable
    public static func toRadians(_ degrees: Double) -> Double {
        degrees * .pi / 180
    }

    /// Converts radians to degrees.
    @inlinable
    public static func toDegrees(_ radians: Double) -> Double {
        radians * 180 / .pi
    }
}
