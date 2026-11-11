import Foundation

/// Steps through a sprite set, honoring each frame's own duration.
@MainActor
final class SpriteAnimator {
    private let sprites: SpriteSet
    private let onFrame: (SpriteFrame) -> Void

    private var frames: [SpriteFrame]
    private(set) var frameIndex = 0
    private(set) var isTalking = false
    private var timer: Timer?

    init(sprites: SpriteSet, onFrame: @escaping (SpriteFrame) -> Void) {
        self.sprites = sprites
        self.onFrame = onFrame
        frames = sprites.idle
    }

    var currentFrame: SpriteFrame? {
        frames.indices.contains(frameIndex) ? frames[frameIndex] : nil
    }

    var isRunning: Bool { timer != nil }

    func start() {
        guard timer == nil else { return }
        showCurrentFrameAndScheduleNext()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Switches to the talk cycle when one was supplied; otherwise the idle
    /// loop simply continues.
    func setTalking(_ talking: Bool) {
        guard talking != isTalking else { return }
        isTalking = talking
        guard let talk = sprites.talk else { return }

        frames = talking ? talk : sprites.idle
        frameIndex = 0
        if isRunning {
            stop()
            start()
        }
    }

    /// Moves to the next frame, wrapping at the end of the cycle.
    func advance() {
        guard !frames.isEmpty else { return }
        frameIndex = (frameIndex + 1) % frames.count
    }

    private func showCurrentFrameAndScheduleNext() {
        guard let frame = currentFrame else { return }
        onFrame(frame)
        // A single-frame sprite has nothing to animate.
        guard frames.count > 1 else { return }
        timer = MainTimer.schedule(after: frame.duration, repeats: false) { [weak self] in
            guard let self else { return }
            self.advance()
            self.showCurrentFrameAndScheduleNext()
        }
    }
}
