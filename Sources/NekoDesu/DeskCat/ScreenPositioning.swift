import CoreGraphics

enum ScreenPositioning {
    /// Window origin for the bottom-left corner of a screen's visible frame.
    /// The visible frame already excludes the Dock and menu bar.
    static func bottomLeftOrigin(in visibleFrame: CGRect) -> CGPoint {
        CGPoint(x: visibleFrame.minX, y: visibleFrame.minY)
    }
}
