import SwiftUI

/// Development fallback shown while no sprite frames are bundled. It is a
/// labeled outline on purpose: supplied artwork is never substituted.
struct DeskCatView: View {
    static let size = CGSize(width: 96, height: 96)

    var body: some View {
        Text(VoiceCatalog.DeskCat.missingSpritesFallback)
            .font(.caption2)
            .multilineTextAlignment(.center)
            .foregroundStyle(.primary)
            .frame(width: Self.size.width - 8, height: Self.size.height - 8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
            .frame(width: Self.size.width, height: Self.size.height)
    }
}
