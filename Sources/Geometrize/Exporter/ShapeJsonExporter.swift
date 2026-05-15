import Foundation

/// Exports `ShapeResult`s as a JSON array compatible with the original Geometrize tools.
public enum ShapeJsonExporter {
    public static func export(_ shapes: [ShapeResult]) -> String {
        "[\n" + exportShapes(shapes) + "\n]"
    }

    public static func exportShapes(_ shapes: [ShapeResult]) -> String {
        var result = ""
        for (i, s) in shapes.enumerated() {
            result += exportShape(s)
            if i != shapes.count - 1 { result += ",\n" }
        }
        return result
    }

    public static func exportShape(_ shape: ShapeResult) -> String {
        var result = "    {\n"
        let type = shape.shape.getType().rawValue
        let data = shape.shape.getRawShapeData()
        let color = shape.color

        result += "        \"type\":\(type),\n"
        result += "        \"data\":["
        for (i, item) in data.enumerated() {
            result += formatNumber(item)
            if i < data.count - 1 { result += "," }
        }
        result += "],\n"

        result += "        \"color\":[\(color.r),\(color.g),\(color.b),\(color.a)],\n"
        result += "        \"score\":\(shape.score)\n"
        result += "    }"
        return result
    }

    private static func formatNumber(_ d: Double) -> String {
        // Integer-valued data (most shape fields) is emitted without a trailing `.0` to match the source.
        if d.truncatingRemainder(dividingBy: 1) == 0 && abs(d) < 1e15 {
            return "\(Int(d))"
        }
        return "\(d)"
    }
}
