import AppKit

enum SpriteHitTesting {
    /// Whether a point in the sprite view (origin bottom-left, in points)
    /// lands on an opaque art pixel.
    static func isOpaque(point: CGPoint, in frame: SpriteFrame, pointsPerArtPixel: Int) -> Bool {
        guard pointsPerArtPixel > 0, point.x >= 0, point.y >= 0 else { return false }
        let x = Int(point.x) / pointsPerArtPixel
        let rowFromBottom = Int(point.y) / pointsPerArtPixel
        return frame.isOpaque(x: x, y: frame.height - 1 - rowFromBottom)
    }
}

/// Draws one sprite frame at a whole-number scale with nearest-neighbor
/// sampling, and accepts clicks only on its opaque pixels.
final class SpriteView: NSView {
    let pointsPerArtPixel: Int
    var onClick: (() -> Void)?

    private(set) var frameShown: SpriteFrame?

    init(artSize: (width: Int, height: Int), pointsPerArtPixel: Int) {
        self.pointsPerArtPixel = pointsPerArtPixel
        super.init(frame: NSRect(
            x: 0,
            y: 0,
            width: artSize.width * pointsPerArtPixel,
            height: artSize.height * pointsPerArtPixel
        ))
        wantsLayer = true
        layer?.magnificationFilter = .nearest
        layer?.minificationFilter = .nearest
        layer?.contentsGravity = .resize
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("SpriteView is created in code")
    }

    func show(_ frame: SpriteFrame) {
        frameShown = frame
        layer?.contents = frame.image
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let frameShown else { return nil }
        let local = convert(point, from: superview)
        let hit = SpriteHitTesting.isOpaque(point: local, in: frameShown, pointsPerArtPixel: pointsPerArtPixel)
        return hit ? self : nil
    }

    // The app is almost never active, so the first click must count.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }
}
