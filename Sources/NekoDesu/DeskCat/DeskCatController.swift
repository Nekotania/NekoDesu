import AppKit
import SwiftUI

struct DeskCatConfiguration {
    /// Idle animation in the app bundle, from `Resources/Catgirl/`.
    var idleResourceName = "Alice"
    /// Optional talk cycle; the idle loop is used when it is absent.
    var talkResourceName = "AliceTalk"
    /// The art is exported with each drawn pixel as a 10×10 block.
    var sourcePixelsPerArtPixel = 10
    /// Whole-number display scale: screen points per drawn pixel.
    var pointsPerArtPixel = 2
    var bubbleWidth: CGFloat = 240
    var bubbleGap: CGFloat = 6
    var bubbleDuration: TimeInterval = 6

    func loadSprites(from bundle: Bundle = .main) -> SpriteSet? {
        guard let idle = frames(named: idleResourceName, in: bundle) else { return nil }
        return SpriteSet(idle: idle, talk: frames(named: talkResourceName, in: bundle))
    }

    private func frames(named name: String, in bundle: Bundle) -> [SpriteFrame]? {
        guard let url = bundle.url(forResource: name, withExtension: "gif") else { return nil }
        return SpriteLoader.loadGIF(at: url, sourcePixelsPerArtPixel: sourcePixelsPerArtPixel)
    }
}

/// Owns the desk-cat window: its lifecycle, placement, animation, and the
/// speech bubble.
@MainActor
final class DeskCatController {
    /// The line for the latest achievement; nil before the first one.
    var latestLine: () -> String? = { nil }

    private let configuration: DeskCatConfiguration
    private let sprites: SpriteSet?
    private let primaryVisibleFrame: () -> CGRect?

    private var window: DeskCatWindow?
    private var spriteView: SpriteView?
    private var bubbleHost: NSHostingView<SpeechBubbleView>?
    private var animator: SpriteAnimator?

    private(set) var speech = DeskCatSpeech()
    private var bubbleTimer: Timer?
    private var placementTimer: Timer?
    private var screenObserver: NSObjectProtocol?

    init(
        configuration: DeskCatConfiguration = DeskCatConfiguration(),
        sprites: SpriteSet?,
        primaryVisibleFrame: @escaping () -> CGRect?
    ) {
        self.configuration = configuration
        self.sprites = sprites
        self.primaryVisibleFrame = primaryVisibleFrame
    }

    /// False when the art could not be loaded; the cat is then omitted.
    var hasSprites: Bool { sprites != nil }
    var isVisible: Bool { window?.isVisible ?? false }
    var windowFrame: CGRect? { window?.frame }

    func show() {
        guard let sprites, let firstFrame = sprites.idle.first else { return }
        let window = self.window ?? makeWindow(sprites: sprites, firstFrame: firstFrame)
        self.window = window

        reposition()
        // Unlike `makeKeyAndOrderFront`, this does not activate the app.
        window.orderFrontRegardless()
        animator?.start()
        startTrackingScreenChanges()
    }

    func hide() {
        closeBubble()
        animator?.stop()
        stopTrackingScreenChanges()
        window?.orderOut(nil)
    }

    /// A rank-up arms one click. Nothing else may call this.
    func arm() {
        speech.arm()
    }

    func handleClick() {
        speech.click(latestLine: latestLine())
        speechDidChange()
    }

    // MARK: Speech bubble

    private func speechDidChange() {
        bubbleTimer?.invalidate()
        bubbleTimer = nil

        let line = speech.visibleLine
        bubbleHost?.rootView = SpeechBubbleView(line: line)
        bubbleHost?.isHidden = line == nil
        animator?.setTalking(line != nil)

        if line != nil {
            bubbleTimer = MainTimer.schedule(after: configuration.bubbleDuration, repeats: false) { [weak self] in
                self?.closeBubble()
            }
        }
    }

    private func closeBubble() {
        speech.dismiss()
        speechDidChange()
    }

    // MARK: Placement

    private func reposition() {
        guard let window, let visibleFrame = primaryVisibleFrame() else { return }
        let origin = ScreenPositioning.bottomLeftOrigin(in: visibleFrame)
        if window.frame.origin != origin {
            window.setFrameOrigin(origin)
        }
    }

    private func startTrackingScreenChanges() {
        guard screenObserver == nil else { return }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reposition() }
        }
        // Moving or resizing the Dock changes the visible frame without
        // posting a screen-parameters notification, so also check slowly.
        placementTimer = MainTimer.schedule(after: 2, repeats: true) { [weak self] in
            self?.reposition()
        }
    }

    private func stopTrackingScreenChanges() {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        screenObserver = nil
        placementTimer?.invalidate()
        placementTimer = nil
    }

    // MARK: Construction

    private func makeWindow(sprites: SpriteSet, firstFrame: SpriteFrame) -> DeskCatWindow {
        let spriteView = SpriteView(
            artSize: (firstFrame.width, firstFrame.height),
            pointsPerArtPixel: configuration.pointsPerArtPixel
        )
        spriteView.onClick = { [weak self] in self?.handleClick() }
        spriteView.show(firstFrame)

        let spriteSize = spriteView.frame.size
        let bubbleHost = NSHostingView(rootView: SpeechBubbleView(line: nil))
        bubbleHost.frame = NSRect(
            x: spriteSize.width + configuration.bubbleGap,
            y: 0,
            width: configuration.bubbleWidth,
            height: spriteSize.height
        )
        bubbleHost.isHidden = true

        let contentSize = CGSize(width: bubbleHost.frame.maxX, height: spriteSize.height)
        let content = NSView(frame: NSRect(origin: .zero, size: contentSize))
        content.addSubview(spriteView)
        content.addSubview(bubbleHost)

        let window = DeskCatWindow(contentSize: contentSize)
        window.contentView = content

        self.spriteView = spriteView
        self.bubbleHost = bubbleHost
        animator = SpriteAnimator(sprites: sprites) { [weak spriteView] frame in
            spriteView?.show(frame)
        }
        return window
    }
}
