import Foundation
@testable import NekoDesu

final class FakePersistenceStore: PersistenceStore {
    var loadResult: PersistenceLoadResult
    var saveError: Error?
    private(set) var saved: [StoredAppState] = []

    init(loadResult: PersistenceLoadResult = PersistenceLoadResult(state: .safeDefaults, diagnostic: nil)) {
        self.loadResult = loadResult
    }

    convenience init(state: StoredAppState) {
        self.init(loadResult: PersistenceLoadResult(state: state, diagnostic: nil))
    }

    func load() -> PersistenceLoadResult { loadResult }

    func save(_ state: StoredAppState) throws {
        if let saveError { throw saveError }
        saved.append(state)
    }
}

final class FakeDiscord: DiscordActivityObserving {
    var observation = DiscordObservation(presence: .notRunning, microphone: .unknown)
    private(set) var observationCount = 0

    func currentObservation() -> DiscordObservation {
        observationCount += 1
        return observation
    }
}

final class FakeNotifications: NotificationService {
    var currentAuthorization: NotificationAuthorization = .notDetermined
    var authorizationAfterRequest: NotificationAuthorization = .authorized
    private(set) var posted: [(identifier: String, title: String, body: String)] = []

    func authorization() async -> NotificationAuthorization { currentAuthorization }

    func requestAuthorization() async -> NotificationAuthorization {
        currentAuthorization = authorizationAfterRequest
        return currentAuthorization
    }

    func post(identifier: String, title: String, body: String) {
        posted.append((identifier, title, body))
    }
}

final class FakeCertificates: CertificateStore {
    var fileExists = false
    var generateError: Error?
    private(set) var generateCount = 0
    private(set) var revealCount = 0

    func exists() -> Bool { fileExists }

    func generate() throws {
        generateCount += 1
        if let generateError { throw generateError }
        fileExists = true
    }

    func revealInFinder() { revealCount += 1 }
}
