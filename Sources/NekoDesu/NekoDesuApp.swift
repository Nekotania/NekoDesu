import AppKit
import SwiftUI

@main
struct NekoDesuApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                model: appDelegate.composition.appModel,
                catEars: appDelegate.composition.catEars,
                ceremony: appDelegate.composition.ceremony,
                richPresence: appDelegate.composition.richPresence,
                deskCatHasSprites: appDelegate.composition.deskCat.hasSprites
            )
        } label: {
            MenuBarIcon(
                appModel: appDelegate.composition.appModel,
                ears: appDelegate.composition.earAnimator
            )
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let composition = CompositionRoot.live()

    // The unit tests are hosted by this app; it must not watch the system or
    // put the cat on screen while they run.
    private let isHostingTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !isHostingTests {
            composition.start()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if !isHostingTests {
            // Credits the last few seconds of an active toggle before exit.
            composition.stop()
        }
    }
}
