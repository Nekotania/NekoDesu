import XCTest
@testable import NekoDesu

@MainActor
final class DeskCatTests: XCTestCase {
    func testWindowCannotTakeKeyboardFocusOrActivate() {
        let window = DeskCatWindow(contentSize: CGSize(width: 96, height: 96))

        XCTAssertFalse(window.canBecomeKey)
        XCTAssertFalse(window.canBecomeMain)
        XCTAssertTrue(window.styleMask.contains(.nonactivatingPanel))
        XCTAssertFalse(window.hidesOnDeactivate)
    }

    func testWindowIsBorderlessTransparentAndOnEverySpace() {
        let window = DeskCatWindow(contentSize: CGSize(width: 96, height: 96))

        XCTAssertFalse(window.styleMask.contains(.titled))
        XCTAssertFalse(window.isOpaque)
        XCTAssertEqual(window.backgroundColor, .clear)
        XCTAssertTrue(window.collectionBehavior.contains(.canJoinAllSpaces))
    }

    func testShowPlacesWindowAtBottomLeftOfVisibleFrameAndHideRemovesIt() {
        let visibleFrame = CGRect(x: 80, y: 70, width: 1440, height: 800)
        let controller = DeskCatController(primaryVisibleFrame: { visibleFrame })
        XCTAssertFalse(controller.isVisible)

        controller.show()
        XCTAssertTrue(controller.isVisible)
        XCTAssertEqual(controller.windowFrame?.origin, visibleFrame.origin)

        controller.hide()
        XCTAssertFalse(controller.isVisible)
    }

    func testBottomLeftOriginUsesVisibleFrameOrigin() {
        // A left-side Dock and a bottom Dock both shift the visible frame.
        let visibleFrame = CGRect(x: 80, y: 70, width: 1440, height: 800)

        XCTAssertEqual(
            ScreenPositioning.bottomLeftOrigin(in: visibleFrame),
            CGPoint(x: 80, y: 70)
        )
    }
}
