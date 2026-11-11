import XCTest
@testable import NekoDesu

final class PersistenceStoreTests: XCTestCase {
    private var directory: URL!
    private var store: FilePersistenceStore!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("NekoDesuTests-\(UUID().uuidString)", isDirectory: true)
        // The store must create its own directory, as on a clean install.
        store = FilePersistenceStore(fileURL: directory.appendingPathComponent("nested/state.json"))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testCleanInstallLoadsSafeDefaultsWithoutDiagnostic() {
        let result = store.load()

        XCTAssertEqual(result.state, .safeDefaults)
        XCTAssertNil(result.diagnostic)
        XCTAssertFalse(result.state.preferences.discordDaddyModeCopyEnabled)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.fileURL.path))
    }

    func testSavedStateRoundTrips() throws {
        var state = StoredAppState.safeDefaults
        state.preferences.discordDaddyModeCopyEnabled = true

        try store.save(state)
        let result = store.load()

        XCTAssertEqual(result.state, state)
        XCTAssertNil(result.diagnostic)
    }

    func testSavedFileRecordsSchemaVersion() throws {
        try store.save(.safeDefaults)

        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: store.fileURL))
        let dictionary = try XCTUnwrap(object as? [String: Any])
        XCTAssertEqual(dictionary["schemaVersion"] as? Int, StoredAppState.currentSchemaVersion)
    }

    func testCorruptFileFallsBackToDefaults() throws {
        try writeRaw("not json at all")

        let result = store.load()

        XCTAssertEqual(result.state, .safeDefaults)
        XCTAssertEqual(result.diagnostic, .corruptData)
    }

    func testCurrentVersionWithWrongShapeFallsBackToDefaults() throws {
        try writeRaw(#"{"schemaVersion": 1, "preferences": "yes"}"#)

        let result = store.load()

        XCTAssertEqual(result.state, .safeDefaults)
        XCTAssertEqual(result.diagnostic, .corruptData)
    }

    func testUnknownSchemaVersionFallsBackToDefaults() throws {
        try writeRaw(#"{"schemaVersion": 999, "preferences": {"discordDaddyModeCopyEnabled": true}}"#)

        let result = store.load()

        XCTAssertEqual(result.state, .safeDefaults)
        XCTAssertEqual(result.diagnostic, .unsupportedSchemaVersion(999))
    }

    private func writeRaw(_ contents: String) throws {
        try FileManager.default.createDirectory(
            at: store.fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(contents.utf8).write(to: store.fileURL)
    }
}
