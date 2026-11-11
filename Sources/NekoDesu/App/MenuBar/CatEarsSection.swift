import SwiftUI

/// Rank, progress, the procrastination toggle, and (until E-Kitten) what the
/// Discord ritual is doing and observing.
struct CatEarsSection: View {
    // Observed because rank and progress are derived from stored state.
    @ObservedObject var appModel: AppModel
    @ObservedObject var catEars: CatEarsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(rankName)
                .font(.title3.weight(.semibold))

            progressView

            Toggle(VoiceCatalog.CatEars.toggle, isOn: Binding(
                get: { catEars.isProcrastinating },
                set: { catEars.setProcrastinating($0) }
            ))
            .toggleStyle(.switch)
            .disabled(catEars.rank == nil)

            if catEars.rank == nil {
                caption(VoiceCatalog.CatEars.toggleLocked)
                ritualExplanation
            }
        }
    }

    private var rankName: String {
        guard let rank = catEars.rank else { return VoiceCatalog.CatEars.unranked }
        return RankTable.entry(for: rank)?.name ?? VoiceCatalog.CatEars.unranked
    }

    @ViewBuilder
    private var progressView: some View {
        switch catEars.progress {
        case .ritual(let fraction):
            progressBar(fraction, caption: VoiceCatalog.CatEars.ritualProgress(percent: Int(fraction * 100)))
        case .towardNext(let next, let minutes, let minutesRequired, let fraction):
            progressBar(fraction, caption: VoiceCatalog.CatEars.progress(
                minutes: minutes,
                minutesRequired: minutesRequired,
                nextRankName: RankTable.entry(for: next)?.name ?? ""
            ))
        case .maximumRank:
            progressBar(1, caption: VoiceCatalog.CatEars.maximumRank)
        }
    }

    private func progressBar(_ fraction: Double, caption text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ProgressView(value: fraction)
                .accessibilityLabel(VoiceCatalog.CatEars.progressLabel)
                .accessibilityValue(text)
            caption(text)
        }
    }

    private var ritualExplanation: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            Text(VoiceCatalog.CatEars.ritualDescription)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            if let observation = catEars.discordObservation {
                caption(VoiceCatalog.CatEars.ritualStatus(for: observation))
            }
            caption(PrivacyDisclosure.funnyDialog)
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
