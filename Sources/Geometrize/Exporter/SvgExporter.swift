import Foundation

/// Exports `ShapeResult`s to SVG.
public enum SvgExporter {
    /// Placeholder embedded in each shape's `getSvgShapeData()` output. Replaced with real styling
    /// during export so shape implementations don't need to know about color/opacity.
    public static let styleHook = "::svg_style_hook::"

    /// Wraps the supplied shapes in a complete SVG document of the given size.
    public static func export(shapes: [ShapeResult], width: Int, height: Int) -> String {
        var result = svgPrelude
        result += svgNodeOpen(width: width, height: height)
        result += exportShapes(shapes)
        result += svgNodeClose
        return result
    }

    /// Concatenates a sequence of shapes into newline-separated SVG fragments.
    public static func exportShapes(_ shapes: [ShapeResult]) -> String {
        var result = ""
        for (i, shape) in shapes.enumerated() {
            result += exportShape(shape)
            if i != shapes.count - 1 { result += "\n" }
        }
        return result
    }

    /// Renders a single shape, substituting the style hook with concrete styling attributes.
    public static func exportShape(_ shape: ShapeResult) -> String {
        shape.shape.getSvgShapeData().replacingOccurrences(of: styleHook, with: stylesForShape(shape))
    }

    public static let svgPrelude = "<?xml version=\"1.0\" standalone=\"no\"?>\n"
    public static let svgNodeClose = "</svg>"
    public static func svgNodeOpen(width: Int, height: Int) -> String {
        "<svg xmlns=\"http://www.w3.org/2000/svg\" version=\"1.2\" baseProfile=\"tiny\" width=\"\(width)\" height=\"\(height)\">\n"
    }

    private static func stylesForShape(_ shape: ShapeResult) -> String {
        switch shape.shape.getType() {
        case .line, .quadraticBezier:
            return "\(strokeForColor(shape.color)) stroke-width=\"1\" fill=\"none\" \(strokeOpacityForAlpha(shape.color.a))"
        default:
            return "\(fillForColor(shape.color)) \(fillOpacityForAlpha(shape.color.a))"
        }
    }

    private static func rgbForColor(_ c: Rgba) -> String { "rgb(\(c.r),\(c.g),\(c.b))" }
    private static func strokeForColor(_ c: Rgba) -> String { "stroke=\"\(rgbForColor(c))\"" }
    private static func fillForColor(_ c: Rgba) -> String { "fill=\"\(rgbForColor(c))\"" }
    private static func fillOpacityForAlpha(_ a: Int) -> String { "fill-opacity=\"\(Double(a) / 255.0)\"" }
    private static func strokeOpacityForAlpha(_ a: Int) -> String { "stroke-opacity=\"\(Double(a) / 255.0)\"" }
}
