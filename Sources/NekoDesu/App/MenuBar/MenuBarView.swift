import AppKit
import SwiftUI

/// The menu bar panel. Feature sections are added here as they are built.
struct MenuBarView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(VoiceCatalog.Panel.title)
                .font(.headline)

            if model.persistenceDiagnostic != nil {
                Text(VoiceCatalog.Panel.storedStateProblem)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            Button(VoiceCatalog.Panel.quit) {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(16)
        .frame(width: 280, alignment: .leading)
    }
}
