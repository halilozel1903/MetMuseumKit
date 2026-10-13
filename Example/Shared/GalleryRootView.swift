import SwiftUI
import MetMuseumKit
import MetMuseumUI

/// What the sidebar can show.
enum SidebarItem: Hashable {
    case highlights
    case search
    case department(Int)
}

/// The whole app, on iPad and on the Mac: a sidebar with Highlights, Search and every department,
/// and a detail column with a grid of works that pushes a work's page.
struct GalleryRootView: View {
    let scene: ScreenshotScene?

    @Environment(GalleryStore.self) private var store
    @State private var selection: SidebarItem?
    @State private var columnVisibility: NavigationSplitViewVisibility
    @State private var path: [Int]

    init(scene: ScreenshotScene?) {
        self.scene = scene
        switch scene {
        case .departments:
            _selection = State(initialValue: .department(ScreenshotScene.browserDepartmentID))
        case .search:
            _selection = State(initialValue: .search)
        default:
            _selection = State(initialValue: .highlights)
        }
        // The iPad scenes show the grid and the work's page full width.
        let fullWidth = scene == .gallery || scene == .object
        _columnVisibility = State(initialValue: fullWidth ? .detailOnly : .all)
        _path = State(initialValue: scene == .object ? [ScreenshotScene.objectID] : [])
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } detail: {
            NavigationStack(path: $path) {
                content
                    .navigationDestination(for: Int.self) { id in
                        ObjectDetailView(objectID: id, scene: scene == .object ? scene : nil)
                    }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: selection) { path = [] }
        .task { await store.loadDepartments() }
    }

    private var sidebar: some View {
        List(selection: $selection) {
            Section("Explore") {
                Label("Highlights", systemImage: "star.square.on.square")
                    .tag(SidebarItem.highlights)
                Label("Search", systemImage: "magnifyingglass")
                    .tag(SidebarItem.search)
            }
            Section("Departments") {
                if let message = store.departmentsError {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if store.departments.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
                ForEach(store.departments) { department in
                    Label(department.displayName, systemImage: DepartmentSymbol.name(for: department.id))
                        .lineLimit(1)
                        .tag(SidebarItem.department(department.id))
                }
            }
        }
        .navigationTitle("The Met")
        .navigationSplitViewColumnWidth(min: 220, ideal: 270, max: 320)
    }

    @ViewBuilder
    private var content: some View {
        switch selection ?? .highlights {
        case .highlights:
            if scene == .object {
                // The object scene opens straight on the work's page; the grid below it would only
                // load images nobody sees.
                Color.clear
            } else {
                HighlightsScreen(scene: scene == .gallery ? scene : nil)
            }
        case .search:
            SearchScreen(scene: scene == .search ? scene : nil)
        case let .department(id):
            DepartmentScreen(
                departmentID: id,
                title: store.department(id: id)?.displayName ?? "Department",
                scene: scene == .departments ? scene : nil
            )
            .id(id)
        }
    }
}

/// A symbol for each department of the collection.
enum DepartmentSymbol {
    static func name(for id: Int) -> String {
        switch id {
        case 1: return "sofa"
        case 3: return "building.columns"
        case 4: return "shield.lefthalf.filled"
        case 5: return "globe.americas"
        case 6: return "leaf"
        case 7: return "building"
        case 8: return "tshirt"
        case 9: return "pencil.and.outline"
        case 10: return "triangle"
        case 11: return "paintpalette"
        case 12: return "figure.stand"
        case 13: return "laurel.leading"
        case 14: return "moon.stars"
        case 15: return "square.stack"
        case 16: return "books.vertical"
        case 17: return "crown"
        case 18: return "guitars"
        case 19: return "camera"
        case 21: return "scribble.variable"
        default: return "square.grid.2x2"
        }
    }
}

/// A value that is loading, loaded or failed.
enum Loadable<Value> {
    case loading
    case loaded(Value)
    case failed(String)

    var value: Value? {
        if case let .loaded(value) = self { return value }
        return nil
    }
}

extension View {
    /// The inline title style with a visible bar on iPad (iOS 26 hides the bar background
    /// otherwise); nothing on the Mac.
    func galleryNavigationStyle() -> some View {
        #if os(iOS)
        return navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
        #else
        return self
        #endif
    }
}
