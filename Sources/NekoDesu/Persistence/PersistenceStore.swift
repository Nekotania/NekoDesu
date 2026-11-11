import Foundation

/// Why stored state could not be used. Carries no stored content.
enum PersistenceDiagnostic: Equatable {
    case unreadableFile
    case corruptData
    case unsupportedSchemaVersion(Int)
    case saveFailed
}

struct PersistenceLoadResult: Equatable {
    var state: StoredAppState
    /// Non-nil when stored data existed but was replaced by safe defaults.
    var diagnostic: PersistenceDiagnostic?
}

protocol PersistenceStore {
    /// Never fails: missing or invalid data yields safe defaults.
    func load() -> PersistenceLoadResult
    func save(_ state: StoredAppState) throws
}

enum AppDirectories {
    /// `~/Library/Application Support/NekoDesu`
    static func applicationSupport(fileManager: FileManager = .default) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("NekoDesu", isDirectory: true)
    }
}

/// Stores state as one JSON file, written atomically.
struct FilePersistenceStore: PersistenceStore {
    let fileURL: URL
    private let fileManager: FileManager

    init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    /// `~/Library/Application Support/NekoDesu/state.json`
    static func defaultFileURL(fileManager: FileManager = .default) -> URL {
        AppDirectories.applicationSupport(fileManager: fileManager).appendingPathComponent("state.json")
    }

    func load() -> PersistenceLoadResult {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return PersistenceLoadResult(state: .safeDefaults, diagnostic: nil)
        }
        guard let data = try? Data(contentsOf: fileURL) else {
            return PersistenceLoadResult(state: .safeDefaults, diagnostic: .unreadableFile)
        }
        return Self.decode(data)
    }

    func save(_ state: StoredAppState) throws {
        var state = state
        state.schemaVersion = StoredAppState.currentSchemaVersion

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)

        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: .atomic)
    }

    static func decode(_ data: Data) -> PersistenceLoadResult {
        struct VersionEnvelope: Decodable {
            let schemaVersion: Int
        }

        let decoder = JSONDecoder()
        guard let envelope = try? decoder.decode(VersionEnvelope.self, from: data) else {
            return PersistenceLoadResult(state: .safeDefaults, diagnostic: .corruptData)
        }

        switch envelope.schemaVersion {
        case StoredAppState.currentSchemaVersion:
            guard let state = try? decoder.decode(StoredAppState.self, from: data), state.isPlausible else {
                return PersistenceLoadResult(state: .safeDefaults, diagnostic: .corruptData)
            }
            return PersistenceLoadResult(state: state, diagnostic: nil)
        case 1:
            guard let old = try? decoder.decode(StoredAppStateV1.self, from: data) else {
                return PersistenceLoadResult(state: .safeDefaults, diagnostic: .corruptData)
            }
            return PersistenceLoadResult(state: old.migrated, diagnostic: nil)
        default:
            return PersistenceLoadResult(
                state: .safeDefaults,
                diagnostic: .unsupportedSchemaVersion(envelope.schemaVersion)
            )
        }
    }
}
