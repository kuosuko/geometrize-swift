import Foundation

/// An RGBA8888 color, packed into a single UInt32 in `RRGGBBAA` byte order.
public struct Rgba: Equatable, Hashable, Sendable {
    public var value: UInt32

    @inlinable
    public init(value: UInt32) {
        self.value = value
    }

    /// Creates a color from individual components in the 0–255 range. Out-of-range values are clamped.
    public init(r: Int, g: Int, b: Int, a: Int) {
        let cr = UInt32(Util.clamp(r, 0, 255))
        let cg = UInt32(Util.clamp(g, 0, 255))
        let cb = UInt32(Util.clamp(b, 0, 255))
        let ca = UInt32(Util.clamp(a, 0, 255))
        self.value = (cr << 24) | (cg << 16) | (cb << 8) | ca
    }

    /// Creates a color from components already known to be in `[0, 255]`. No clamping.
    /// Internal-only hot-path constructor.
    @inlinable
    init(uncheckedR r: Int, g: Int, b: Int, a: Int) {
        self.value = (UInt32(truncatingIfNeeded: r) << 24)
                   | (UInt32(truncatingIfNeeded: g) << 16)
                   | (UInt32(truncatingIfNeeded: b) << 8)
                   |  UInt32(truncatingIfNeeded: a)
    }

    @inlinable public var r: Int { Int((value >> 24) & 0xFF) }
    @inlinable public var g: Int { Int((value >> 16) & 0xFF) }
    @inlinable public var b: Int { Int((value >> 8) & 0xFF) }
    @inlinable public var a: Int { Int(value & 0xFF) }

    public static let transparent = Rgba(value: 0)
    public static let opaqueBlack = Rgba(r: 0, g: 0, b: 0, a: 255)
    public static let opaqueWhite = Rgba(r: 255, g: 255, b: 255, a: 255)
}
