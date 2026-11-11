import AppKit
import SwiftUI

/// Owns the desk-cat window's lifecycle and placement.
@MainActor
final class DeskCatController {
    private let primaryVisibleFrame: () -> CGRect?
    private var window: DeskCatWindow?

    init(primaryVisibleFrame: @escaping () -> CGRect?) {
        self.primaryVisibleFrame = primaryVisibleFrame
    }

    var isVisible: Bool { window?.isVisible ?? false }
    var windowFrame: CGRect? { window?.frame }

    func show() {
        let window = self.window ?? makeWindow()
        self.window = window

        if let visibleFrame = primaryVisibleFrame() {
            window.setFrameOrigin(ScreenPositioning.bottomLeftOrigin(in: visibleFrame))
        }
        // Unlike `makeKeyAndOrderFront`, this does not activate the app.
        window.orderFrontRegardless()
    }

    func hide() {
        window?.orderOut(nil)
    }

    private func makeWindow() -> DeskCatWindow {
        let window = DeskCatWindow(contentSize: DeskCatView.size)
        window.contentView = NSHostingView(rootView: DeskCatView())
        return window
    }
}
