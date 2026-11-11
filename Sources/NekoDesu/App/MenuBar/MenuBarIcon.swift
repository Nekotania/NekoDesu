import SwiftUI

struct MenuBarIcon: View {
    var body: some View {
        Image(systemName: "pawprint.fill")
            .accessibilityLabel(VoiceCatalog.Panel.title)
    }
}
