import AppKit
import SwiftUI

/// Plays the short ear wiggle on the menu bar icon after a rank-up.
@MainActor
final class EarAnimator: ObservableObject {
    /// Extra ear height in points; 0 at rest.
    @Published private(set) var earOffset: CGFloat = 0

    private static let offsets: [CGFloat] = [1, 2, 3, 2, 0, -1, 0, 2, 3, 2, 1, 0]
    private static let frameDuration: TimeInterval = 0.08

    private var timer: Timer?
    private var step = 0

    func play() {
        timer?.invalidate()
        step = 0
        timer = MainTimer.schedule(after: Self.frameDuration, repeats: true) { [weak self] in
            self?.advance()
        }
    }

    private func advance() {
        guard step < Self.offsets.count else {
            timer?.invalidate()
            timer = nil
            earOffset = 0
            return
        }
        earOffset = Self.offsets[step]
        step += 1
    }
}

/// A cat head whose ears grow with rank: none before E-Kitten, tallest at
/// the top rank.
struct MenuBarIcon: View {
    @ObservedObject var appModel: AppModel
    @ObservedObject var ears: EarAnimator

    var body: some View {
        Image(nsImage: MenuBarIconRenderer.image(earHeight: earHeight))
            .accessibilityLabel(VoiceCatalog.Panel.title)
    }

    private var earHeight: CGFloat {
        guard let rank = appModel.stored.catEars.rank else { return 0 }
        return MenuBarIconRenderer.restingEarHeight(for: rank) + ears.earOffset
    }
}

enum MenuBarIconRenderer {
    static let size = NSSize(width: 18, height: 18)
    private static let headRect = NSRect(x: 2, y: 1, width: 14, height: 9)
    private static let maximumEarHeight: CGFloat = 8

    /// 3 points at E-Kitten, one more per rank.
    static func restingEarHeight(for rank: Rank) -> CGFloat {
        CGFloat(3 + (RankTable.index(of: rank) ?? 0))
    }

    static func image(earHeight: CGFloat) -> NSImage {
        let height = min(max(earHeight, 0), maximumEarHeight)
        let image = NSImage(size: size, flipped: false) { _ in
            NSColor.black.setFill()
            NSBezierPath(ovalIn: headRect).fill()
            if height > 0 {
                ear(baseLeft: 2.5, baseRight: 8, apexX: 3.5, height: height).fill()
                ear(baseLeft: 10, baseRight: 15.5, apexX: 14.5, height: height).fill()
            }
            return true
        }
        // Template images follow the menu bar's light or dark appearance.
        image.isTemplate = true
        return image
    }

    private static func ear(baseLeft: CGFloat, baseRight: CGFloat, apexX: CGFloat, height: CGFloat) -> NSBezierPath {
        let baseY = headRect.midY + 1
        let path = NSBezierPath()
        path.move(to: NSPoint(x: baseLeft, y: baseY))
        path.line(to: NSPoint(x: baseRight, y: baseY + 2))
        path.line(to: NSPoint(x: apexX, y: headRect.maxY + height))
        path.close()
        return path
    }
}
