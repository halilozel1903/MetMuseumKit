import SwiftUI
import MetMuseumKit
import MetMuseumUI

/// Met Gallery for the Mac: the department browser, highlights and search of The Met's
/// collection, with Open Access images loaded live from images.metmuseum.org.
@main
struct MetGalleryMacApp: App {
    @State private var store: GalleryStore
    private let scene = ScreenshotScene.current

    init() {
        _store = State(initialValue: GalleryStore.make(for: ScreenshotScene.current))
    }

    var body: some Scene {
        WindowGroup("Met Gallery") {
            GalleryRootView(scene: scene)
                .environment(store)
                .metImageLoader(scene == nil ? MetImageLoader.urlSession : ScreenshotScene.imageLoader)
                .frame(minWidth: 980, minHeight: 640)
                .preferredColorScheme(scene == nil ? nil : .dark)
                .tint(GalleryTheme.accent)
                .background {
                    if let scene {
                        ScreenshotWindow(scene: scene)
                    }
                }
        }
        .defaultSize(width: 1440, height: 900)
    }
}
