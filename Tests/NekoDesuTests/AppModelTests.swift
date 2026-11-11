import XCTest
@testable import NekoDesu

@MainActor
final class AppModelTests: XCTestCase {
    func testStartsFromWhatTheStoreLoads() {
        var state = StoredAppState.safeDefaults
        state.preferences.discordDaddyModeCopyEnabled = true
        let store = FakePersistenceStore(loadResult: PersistenceLoadResult(state: state, diagnostic: nil))

        let model = AppModel(persistence: store)

        XCTAssertEqual(model.stored, state)
        XCTAssertNil(model.persistenceDiagnostic)
    }

    func testSurfacesLoadDiagnostic() {
        let store = FakePersistenceStore(
            loadResult: PersistenceLoadResult(state: .safeDefaults, diagnostic: .corruptData)
        )

        let model = AppModel(persistence: store)

        XCTAssertEqual(model.stored, .safeDefaults)
        XCTAssertEqual(model.persistenceDiagnostic, .corruptData)
    }

    func testUpdateSavesTheChange() {
        let store = FakePersistenceStore()
        let model = AppModel(persistence: store)

        model.update { $0.preferences.discordDaddyModeCopyEnabled = true }

        XCTAssertTrue(model.stored.preferences.discordDaddyModeCopyEnabled)
        XCTAssertEqual(store.saved.count, 1)
        XCTAssertEqual(store.saved.last, model.stored)
    }

    func testUpdateWithoutAChangeDoesNotSave() {
        let store = FakePersistenceStore()
        let model = AppModel(persistence: store)

        model.update { $0.preferences.discordDaddyModeCopyEnabled = false }

        XCTAssertTrue(store.saved.isEmpty)
    }

    func testFailedSaveKeepsTheChangeAndReportsIt() {
        let store = FakePersistenceStore()
        store.saveError = CocoaError(.fileWriteNoPermission)
        let model = AppModel(persistence: store)

        model.update { $0.preferences.discordDaddyModeCopyEnabled = true }

        XCTAssertTrue(model.stored.preferences.discordDaddyModeCopyEnabled)
        XCTAssertEqual(model.persistenceDiagnostic, .saveFailed)
    }
}

private final class FakePersistenceStore: PersistenceStore {
    var loadResult: PersistenceLoadResult
    var saveError: Error?
    private(set) var saved: [StoredAppState] = []

    init(loadResult: PersistenceLoadResult = PersistenceLoadResult(state: .safeDefaults, diagnostic: nil)) {
        self.loadResult = loadResult
    }

    func load() -> PersistenceLoadResult { loadResult }

    func save(_ state: StoredAppState) throws {
        if let saveError { throw saveError }
        saved.append(state)
    }
}
