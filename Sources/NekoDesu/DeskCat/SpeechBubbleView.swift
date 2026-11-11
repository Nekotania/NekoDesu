import SwiftUI

struct SpeechBubbleView: View {
    let line: String?

    var body: some View {
        ZStack(alignment: .leading) {
            if let line {
                Text(line)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(10)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.secondary.opacity(0.5)))
                    .accessibilityLabel(line)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
