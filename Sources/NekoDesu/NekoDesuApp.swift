import AppKit
import SwiftUI

@main
struct NekoDesuApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(model: appDelegate.composition.appModel)
        } label: {
            MenuBarIcon()
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let composition = CompositionRoot.live()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // The unit tests are hosted by this app; keep the cat off screen for them.
        let isHostingTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        if !isHostingTests {
            composition.deskCat.show()
        }
    }
}
