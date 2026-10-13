import SwiftUI
import MetMuseumKit
import MetMuseumUI

/// A grid of works that link to their pages.
struct ArtworkGrid: View {
    let objects: [MetObject]

    private let columns = [GridItem(.adaptive(minimum: 190, maximum: 280), spacing: 20, alignment: .top)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 26) {
            ForEach(objects) { object in
                NavigationLink(value: object.id) {
                    ArtworkCard(object: object, showsBadge: true)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// A title with a line below it, above a grid.
struct GridHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(.largeTitle, design: .serif).weight(.semibold))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

/// Highlights of one department that are in the public domain and have an image, with a menu to
/// pick the department. Opens on European Paintings.
struct HighlightsScreen: View {
    let scene: ScreenshotScene?

    @Environment(GalleryStore.self) private var store
    @State private var departmentID = ScreenshotScene.galleryDepartmentID
    @State private var state: Loadable<[MetObject]> = .loading

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                GridHeader(
                    title: "Highlights",
                    subtitle: (store.department(id: departmentID)?.displayName ?? "European Paintings")
                        + " · highlighted works in the public domain"
                )
                switch state {
                case .loading:
                    ProgressView().frame(maxWidth: .infinity, minHeight: 300)
                case let .failed(message):
                    ContentUnavailableView("Couldn't load highlights", systemImage: "wifi.exclamationmark", description: Text(message))
                case let .loaded(objects):
                    ArtworkGrid(objects: objects)
                    MetOpenAccessCredit()
                }
            }
            .padding(24)
        }
        .navigationTitle("Highlights")
        .galleryNavigationStyle()
        .toolbar {
            ToolbarItem {
                Menu {
                    Picker("Department", selection: $departmentID) {
                        ForEach(store.departments) { department in
                            Text(department.displayName).tag(department.id)
                        }
                    }
                } label: {
                    Label("Department", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .task(id: departmentID) {
            state = .loading
            do {
                state = .loaded(try await store.highlights(departmentID: departmentID))
            } catch {
                // A newer load replaced this one; it sets its own state.
                if !Task.isCancelled {
                    state = .failed(error.localizedDescription)
                }
            }
        }
        .signalsScreenshotReady(scene, when: (state.value?.count ?? 0) >= 8, minimumImages: 8)
    }
}

/// One department's highlights that are in the public domain and have an image.
struct DepartmentScreen: View {
    let departmentID: Int
    let title: String
    let scene: ScreenshotScene?

    @Environment(GalleryStore.self) private var store
    @State private var state: Loadable<[MetObject]> = .loading

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                GridHeader(title: title, subtitle: subtitle)
                switch state {
                case .loading:
                    ProgressView().frame(maxWidth: .infinity, minHeight: 300)
                case let .failed(message):
                    ContentUnavailableView("Couldn't load the department", systemImage: "wifi.exclamationmark", description: Text(message))
                case let .loaded(objects):
                    if objects.isEmpty {
                        ContentUnavailableView("No public domain highlights", systemImage: "photo.on.rectangle.angled")
                    } else {
                        ArtworkGrid(objects: objects)
                    }
                    MetOpenAccessCredit()
                }
            }
            .padding(24)
        }
        .navigationTitle(title)
        .galleryNavigationStyle()
        .task {
            do {
                state = .loaded(try await store.highlights(departmentID: departmentID))
            } catch {
                // A newer load replaced this one; it sets its own state.
                if !Task.isCancelled {
                    state = .failed(error.localizedDescription)
                }
            }
        }
        .signalsScreenshotReady(scene, when: (state.value?.count ?? 0) >= 6, minimumImages: 6)
    }

    private var subtitle: String {
        guard let objects = state.value else { return "Department " + String(departmentID) }
        return "\(objects.count) highlighted works with Open Access images"
    }
}

/// Search the collection, with filters for highlights, department and public domain.
struct SearchScreen: View {
    let scene: ScreenshotScene?

    @Environment(GalleryStore.self) private var store
    @State private var text: String
    @State private var submitted: String
    @State private var highlightsOnly = false
    @State private var publicDomainOnly = true
    @State private var departmentID: Int?
    @State private var state: Loadable<SearchResult>?

    init(scene: ScreenshotScene?) {
        self.scene = scene
        let initial = scene == .search ? ScreenshotScene.searchText : ""
        _text = State(initialValue: initial)
        _submitted = State(initialValue: initial)
    }

    private struct Key: Hashable {
        var text: String
        var highlightsOnly: Bool
        var publicDomainOnly: Bool
        var departmentID: Int?
    }

    private var key: Key {
        Key(text: submitted, highlightsOnly: highlightsOnly, publicDomainOnly: publicDomainOnly, departmentID: departmentID)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                filters
                results
            }
            .padding(24)
        }
        .navigationTitle("Search")
        .galleryNavigationStyle()
        .searchable(text: $text, prompt: "Artist, title, culture, medium…")
        .onSubmit(of: .search) { submitted = text.trimmingCharacters(in: .whitespaces) }
        .task(id: key) { await run() }
        .signalsScreenshotReady(scene, when: (state?.value?.objects.count ?? 0) >= 6, minimumImages: 6)
    }

    private var filters: some View {
        HStack(spacing: 16) {
            Toggle("Public domain only", isOn: $publicDomainOnly)
            Toggle("Highlights only", isOn: $highlightsOnly)
            Picker("Department", selection: $departmentID) {
                Text("All departments").tag(Int?.none)
                ForEach(store.departments) { department in
                    Text(department.displayName).tag(Int?.some(department.id))
                }
            }
            .fixedSize()
            Spacer(minLength: 0)
        }
        .toggleStyle(.button)
    }

    @ViewBuilder
    private var results: some View {
        switch state {
        case nil:
            ContentUnavailableView("Search the collection", systemImage: "magnifyingglass", description: Text("Over 470,000 works, from every department of The Met."))
        case .loading?:
            ProgressView().frame(maxWidth: .infinity, minHeight: 300)
        case let .failed(message)?:
            ContentUnavailableView("Search failed", systemImage: "wifi.exclamationmark", description: Text(message))
        case let .loaded(result)?:
            if result.objects.isEmpty {
                ContentUnavailableView.search(text: submitted)
            } else {
                GridHeader(
                    title: "“" + submitted + "”",
                    subtitle: "\(result.total) matches · showing \(result.objects.count) "
                        + (publicDomainOnly ? "public domain works with images" : "works with images")
                )
                ArtworkGrid(objects: result.objects)
                MetOpenAccessCredit()
            }
        }
    }

    private func run() async {
        guard !submitted.isEmpty else {
            state = nil
            return
        }
        state = .loading
        let query = MetSearchQuery(
            submitted,
            isHighlight: highlightsOnly ? true : nil,
            hasImages: true,
            departmentID: departmentID
        )
        do {
            state = .loaded(try await store.search(query, publicDomainOnly: publicDomainOnly))
        } catch {
            // A newer search replaced this one; it sets its own state.
            if !Task.isCancelled {
                state = .failed(error.localizedDescription)
            }
        }
    }
}
