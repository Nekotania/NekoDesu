import XCTest
@testable import NekoDesu

@MainActor
final class DeskCatTests: XCTestCase {
    // MARK: Window

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

    func testBottomLeftOriginUsesVisibleFrameOrigin() {
        // A left-side Dock and a bottom Dock both shift the visible frame.
        let visibleFrame = CGRect(x: 80, y: 70, width: 1440, height: 800)

        XCTAssertEqual(
            ScreenPositioning.bottomLeftOrigin(in: visibleFrame),
            CGPoint(x: 80, y: 70)
        )
    }

    // MARK: Sprites

    /// A 4×2-art-pixel test image enlarged by `blockSize`: top row opaque
    /// red, bottom row transparent.
    private func makeEnlargedImage(blockSize: Int) throws -> CGImage {
        let width = 4 * blockSize
        let height = 2 * blockSize
        let context = try XCTUnwrap(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
        // CoreGraphics' origin is bottom-left, so this fills the top row.
        context.fill(CGRect(x: 0, y: blockSize, width: width, height: blockSize))
        return try XCTUnwrap(context.makeImage())
    }

    private func makeFrame(duration: TimeInterval = 0.1) throws -> SpriteFrame {
        try XCTUnwrap(SpriteLoader.reduce(try makeEnlargedImage(blockSize: 10), by: 10, duration: duration))
    }

    func testReducingRecoversTheNativeGrid() throws {
        let frame = try makeFrame()

        XCTAssertEqual(frame.width, 4)
        XCTAssertEqual(frame.height, 2)
        XCTAssertEqual(frame.image.width, 4)
        XCTAssertEqual(frame.image.height, 2)
        for x in 0..<4 {
            XCTAssertTrue(frame.isOpaque(x: x, y: 0))
            XCTAssertFalse(frame.isOpaque(x: x, y: 1))
        }
        XCTAssertFalse(frame.isOpaque(x: -1, y: 0))
        XCTAssertFalse(frame.isOpaque(x: 4, y: 0))
    }

    func testReducingRejectsSizesThatAreNotWholeBlocks() throws {
        let image = try makeEnlargedImage(blockSize: 10)

        XCTAssertNil(SpriteLoader.reduce(image, by: 3, duration: 0.1))
        XCTAssertNil(SpriteLoader.reduce(image, by: 0, duration: 0.1))
    }

    func testBundledArtLoadsAsSixtyFourPixelFramesWithItsOwnTiming() throws {
        let sprites = try XCTUnwrap(DeskCatConfiguration().loadSprites(from: .main))

        XCTAssertEqual(sprites.idle.count, 15)
        XCTAssertTrue(sprites.idle.allSatisfy { $0.width == 64 && $0.height == 64 })
        XCTAssertEqual(sprites.idle[0].duration, 0.1, accuracy: 0.0001)
        XCTAssertEqual(sprites.idle[14].duration, 0.02, accuracy: 0.0001)
        // Transparent corner, opaque somewhere in the middle.
        XCTAssertFalse(sprites.idle[0].isOpaque(x: 0, y: 0))
        XCTAssertTrue(sprites.idle[0].isOpaque(x: 30, y: 30))
        // No talk cycle is supplied; the idle loop stands in for it.
        XCTAssertNil(sprites.talk)
    }

    func testMissingArtYieldsNoSprites() {
        var configuration = DeskCatConfiguration()
        configuration.idleResourceName = "NoSuchCat"

        XCTAssertNil(configuration.loadSprites(from: .main))
    }

    func testSpriteViewScalesByAWholeNumberWithNearestNeighborSampling() throws {
        let view = SpriteView(artSize: (64, 64), pointsPerArtPixel: 2)

        XCTAssertEqual(view.frame.size, CGSize(width: 128, height: 128))
        XCTAssertEqual(view.layer?.magnificationFilter, .nearest)
        XCTAssertEqual(view.layer?.minificationFilter, .nearest)
    }

    func testHitTestingAcceptsOnlyOpaquePixels() throws {
        let frame = try makeFrame()
        // At 3 points per art pixel the view is 12×6; the opaque row is the
        // top half, which is y 3..<6 in view coordinates.
        func hit(_ x: CGFloat, _ y: CGFloat) -> Bool {
            SpriteHitTesting.isOpaque(point: CGPoint(x: x, y: y), in: frame, pointsPerArtPixel: 3)
        }

        XCTAssertTrue(hit(0, 3))
        XCTAssertTrue(hit(11.9, 5.9))
        XCTAssertFalse(hit(0, 0))
        XCTAssertFalse(hit(6, 2.9))
        XCTAssertFalse(hit(12, 4))
        XCTAssertFalse(hit(-1, 4))
        XCTAssertFalse(hit(4, 6))
    }

    func testSpriteViewHitTestFollowsTheFrameShown() throws {
        let view = SpriteView(artSize: (4, 2), pointsPerArtPixel: 3)
        XCTAssertNil(view.hitTest(NSPoint(x: 1, y: 4)))

        view.show(try makeFrame())

        XCTAssertTrue(view.hitTest(NSPoint(x: 1, y: 4)) === view)
        XCTAssertNil(view.hitTest(NSPoint(x: 1, y: 1)))
    }

    func testAnimatorLoopsIdleFrames() throws {
        let frames = [try makeFrame(), try makeFrame(), try makeFrame()]
        let animator = SpriteAnimator(sprites: SpriteSet(idle: frames, talk: nil)) { _ in }

        XCTAssertEqual(animator.frameIndex, 0)
        animator.advance()
        animator.advance()
        XCTAssertEqual(animator.frameIndex, 2)
        animator.advance()
        XCTAssertEqual(animator.frameIndex, 0)
    }

    func testAnimatorUsesTalkCycleOnlyWhenSupplied() throws {
        let idle = [try makeFrame(), try makeFrame()]
        let talk = [try makeFrame(duration: 0.3)]

        let withoutTalk = SpriteAnimator(sprites: SpriteSet(idle: idle, talk: nil)) { _ in }
        withoutTalk.advance()
        withoutTalk.setTalking(true)
        XCTAssertEqual(withoutTalk.frameIndex, 1)
        XCTAssertEqual(withoutTalk.currentFrame?.duration, 0.1)

        let withTalk = SpriteAnimator(sprites: SpriteSet(idle: idle, talk: talk)) { _ in }
        withTalk.advance()
        withTalk.setTalking(true)
        XCTAssertEqual(withTalk.frameIndex, 0)
        XCTAssertEqual(withTalk.currentFrame?.duration, 0.3)
        withTalk.setTalking(false)
        XCTAssertEqual(withTalk.currentFrame?.duration, 0.1)
    }

    // MARK: Speech

    func testClicksDoNothingBeforeTheFirstAchievement() {
        var speech = DeskCatSpeech()

        speech.click(latestLine: nil)

        XCTAssertNil(speech.visibleLine)
        XCTAssertFalse(speech.isArmed)
    }

    func testArmedClickOpensTheBubbleAndConsumesTheArm() {
        var speech = DeskCatSpeech()
        speech.arm()
        XCTAssertTrue(speech.isArmed)

        speech.click(latestLine: "line")

        XCTAssertEqual(speech.visibleLine, "line")
        XCTAssertFalse(speech.isArmed)
    }

    func testSecondClickClosesAndFurtherClicksRepeatTheLatestLine() {
        var speech = DeskCatSpeech()
        speech.arm()
        speech.click(latestLine: "line")

        speech.click(latestLine: "line")
        XCTAssertNil(speech.visibleLine)

        speech.click(latestLine: "line")
        XCTAssertEqual(speech.visibleLine, "line")

        speech.dismiss()
        XCTAssertNil(speech.visibleLine)
    }

    // MARK: Controller

    private func makeController(
        sprites: SpriteSet?,
        visibleFrame: CGRect = CGRect(x: 80, y: 70, width: 1440, height: 800)
    ) -> DeskCatController {
        var configuration = DeskCatConfiguration()
        configuration.bubbleDuration = 60
        return DeskCatController(configuration: configuration, sprites: sprites, primaryVisibleFrame: { visibleFrame })
    }

    func testShowPlacesWindowAtBottomLeftOfVisibleFrameAndHideRemovesIt() throws {
        let controller = makeController(sprites: SpriteSet(idle: [try makeFrame()], talk: nil))
        XCTAssertFalse(controller.isVisible)

        controller.show()
        XCTAssertTrue(controller.isVisible)
        XCTAssertEqual(controller.windowFrame?.origin, CGPoint(x: 80, y: 70))

        controller.hide()
        XCTAssertFalse(controller.isVisible)
    }

    func testCatIsOmittedWhenArtIsMissing() {
        let controller = makeController(sprites: nil)

        controller.show()

        XCTAssertFalse(controller.hasSprites)
        XCTAssertFalse(controller.isVisible)
    }

    func testClickShowsTheLatestLineOnlyAfterAnAchievement() throws {
        let controller = makeController(sprites: SpriteSet(idle: [try makeFrame()], talk: nil))
        controller.show()
        defer { controller.hide() }

        controller.handleClick()
        XCTAssertNil(controller.speech.visibleLine)

        controller.latestLine = { "Stray Cat line" }
        controller.arm()
        controller.handleClick()
        XCTAssertEqual(controller.speech.visibleLine, "Stray Cat line")
        XCTAssertFalse(controller.speech.isArmed)

        controller.handleClick()
        XCTAssertNil(controller.speech.visibleLine)
    }
}
