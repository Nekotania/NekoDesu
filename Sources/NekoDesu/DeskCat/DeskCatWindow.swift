import AppKit

/// Borderless, transparent window that never activates the app or takes
/// keyboard focus.
final class DeskCatWindow: NSPanel {
    init(contentSize: CGSize) {
        super.init(
            contentRect: NSRect(origin: .zero, size: contentSize),
            // `.nonactivatingPanel` is only honored by NSPanel; it lets the window
            // receive clicks without bringing NekoDesu to the front.
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
        // `ignoresMouseEvents` is deliberately left untouched: while it has
        // never been set, macOS passes clicks on fully transparent pixels
        // through to whatever is underneath. Setting it, even to false, turns
        // that off and makes the whole rectangle swallow clicks.
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
