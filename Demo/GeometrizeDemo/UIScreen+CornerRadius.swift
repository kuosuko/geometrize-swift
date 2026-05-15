import UIKit

extension UIScreen {
    /// The hardware display's corner radius. Reads the private `_displayCornerRadius` key —
    /// falls back to 41.5 (iPhone X-series default) if the lookup fails.
    static var displayCornerRadiusAdjusted: CGFloat {
        guard let radius = UIScreen.main.value(forKey: "_displayCornerRadius") as? CGFloat else {
            return 41.5
        }
        return radius
    }

    /// Returns a corner radius concentric with the display corner — i.e. the right value to
    /// use on a surface that's inset by `inset` points from the hardware edge.
    static func concentricRadius(inset: CGFloat) -> CGFloat {
        max(displayCornerRadiusAdjusted - inset, 8)
    }
}
