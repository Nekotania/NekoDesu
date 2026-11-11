import Foundation

/// Top-level app state: owns the persisted state and writes every change back.
@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var stored: StoredAppState
    @Published private(set) var persistenceDiagnostic: PersistenceDiagnostic?

    private let persistence: PersistenceStore

    init(persistence: PersistenceStore) {
        self.persistence = persistence
        let loaded = persistence.load()
        stored = loaded.state
        persistenceDiagnostic = loaded.diagnostic
    }

    /// Applies a change to the persisted state and saves it.
    func update(_ change: (inout StoredAppState) -> Void) {
        var updated = stored
        change(&updated)
        guard updated != stored else { return }
        stored = updated

        do {
            try persistence.save(updated)
            persistenceDiagnostic = nil
        } catch {
            persistenceDiagnostic = .saveFailed
        }
    }
}
