import Foundation

/// Main-run-loop timers whose callbacks run on the main actor.
enum MainTimer {
    /// The caller owns the returned timer and must invalidate it.
    static func schedule(
        after interval: TimeInterval,
        repeats: Bool,
        action: @escaping @MainActor () -> Void
    ) -> Timer {
        let timer = Timer(timeInterval: interval, repeats: repeats) { _ in
            MainActor.assumeIsolated { action() }
        }
        // `.common` keeps the timer firing while a menu or the panel is tracking.
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }
}
