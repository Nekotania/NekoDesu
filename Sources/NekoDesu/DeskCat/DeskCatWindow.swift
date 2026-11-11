import AppKit

/// Borderless, transparent window that never activates the app or takes
/// keyboard focus.
final class DeskCatWindow: NSPanel {
    init(contentSize: CGSize) {
        super.init(
            contentRect: NSRect(origin: .zero, size: contentSize),
            // `.nonactivatingPanel` is only honored by NSPanel; it lets the window
            // receive events without bringing NekoDesu to the front.
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        // NSPanel hides itself when its app is inactive unless told otherwise,
        // and a menu bar app is almost always inactive.
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        // Clicks pass through until sprite hit testing exists.
        ignoresMouseEvents = true
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
