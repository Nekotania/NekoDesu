import AppKit
import SwiftUI

/// The menu bar panel. Feature sections are added here as they are built.
struct MenuBarView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var catEars: CatEarsModel
    @ObservedObject var ceremony: RankCeremony
    let deskCatHasSprites: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(VoiceCatalog.Panel.title)
                .font(.headline)

            if model.persistenceDiagnostic != nil {
                note(VoiceCatalog.Panel.storedStateProblem)
            }

            CatEarsSection(appModel: model, catEars: catEars)

            if catEars.rank != nil {
                certificateRow
            }
            notificationsRow

            if !deskCatHasSprites {
                note(VoiceCatalog.DeskCat.missingSprites)
            }

            Divider()

            Toggle(VoiceCatalog.Settings.discordDaddyMode, isOn: Binding(
                get: { model.stored.preferences.discordDaddyModeCopyEnabled },
                set: { catEars.setDiscordDaddyModeEnabled($0) }
            ))

            Button(VoiceCatalog.Panel.quit) {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(16)
        .frame(width: 300, alignment: .leading)
        .task {
            await ceremony.refresh()
        }
    }

    @ViewBuilder
    private var certificateRow: some View {
        switch ceremony.certificateState {
        case .available:
            Button(VoiceCatalog.Certificate.reveal) { ceremony.revealCertificate() }
        case .missing:
            Button(VoiceCatalog.Certificate.create) { ceremony.createCertificate() }
        case .failed:
            note(VoiceCatalog.Certificate.failed)
            Button(VoiceCatalog.Certificate.create) { ceremony.createCertificate() }
        }
    }

    @ViewBuilder
    private var notificationsRow: some View {
        switch ceremony.notificationAuthorization {
        case .authorized:
            EmptyView()
        case .notDetermined:
            note(VoiceCatalog.Notifications.explanation)
            Button(VoiceCatalog.Notifications.allow) {
                Task { await ceremony.requestNotificationAuthorization() }
            }
        case .denied:
            note(VoiceCatalog.Notifications.denied)
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
