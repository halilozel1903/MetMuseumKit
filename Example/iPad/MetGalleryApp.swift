import SwiftUI
import MetMuseumKit
import MetMuseumUI

/// Met Gallery for iPad: highlights, search and every department of The Met's collection, with
/// Open Access images loaded live from images.metmuseum.org.
@main
struct MetGalleryApp: App {
    @State private var store: GalleryStore
    private let scene = ScreenshotScene.current

    init() {
        _store = State(initialValue: GalleryStore.make(for: ScreenshotScene.current))
    }

    var body: some Scene {
        WindowGroup {
            GalleryRootView(scene: scene)
                .environment(store)
                // Screenshot scenes count their image loads, to report ready once all are on screen.
                .metImageLoader(scene == nil ? MetImageLoader.urlSession : ScreenshotScene.imageLoader)
                .preferredColorScheme(scene == nil ? nil : .dark)
                .tint(GalleryTheme.accent)
        }
    }
}
