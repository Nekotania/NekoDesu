import AppKit

/// The one place where feature models and system adapters are constructed.
@MainActor
struct CompositionRoot {
    let appModel: AppModel
    let deskCat: DeskCatController

    static func live() -> CompositionRoot {
        let persistence = FilePersistenceStore(fileURL: FilePersistenceStore.defaultFileURL())
        return CompositionRoot(
            appModel: AppModel(persistence: persistence),
            deskCat: DeskCatController(primaryVisibleFrame: {
                // `screens.first` is the display with the menu bar; `NSScreen.main`
                // would follow whichever screen has keyboard focus.
                NSScreen.screens.first?.visibleFrame
            })
        )
    }
}
