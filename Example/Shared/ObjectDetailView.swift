import SwiftUI
import MetMuseumKit
import MetMuseumUI

/// A work's page: the image, the title and artist, and the catalogue facts.
struct ObjectDetailView: View {
    let objectID: Int
    let scene: ScreenshotScene?

    @Environment(GalleryStore.self) private var store
    @State private var state: Loadable<MetObject> = .loading

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case let .failed(message):
                ContentUnavailableView("Couldn't load this work", systemImage: "wifi.exclamationmark", description: Text(message))
            case let .loaded(object):
                ObjectPage(object: object)
            }
        }
        .navigationTitle(state.value?.displayTitle ?? "Artwork")
        .galleryNavigationStyle()
        .task(id: objectID) {
            do {
                state = .loaded(try await store.object(id: objectID))
            } catch {
                if !Task.isCancelled {
                    state = .failed(error.localizedDescription)
                }
            }
        }
        .signalsScreenshotReady(scene, when: state.value?.hasPublicDomainImage == true, minimumImages: 1)
    }
}

private struct ObjectPage: View {
    let object: MetObject

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                MetArtworkImage(object: object, size: .small, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(height: 560)
                    .padding(.vertical, 8)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        if object.isPublicDomain {
                            PublicDomainBadge()
                        }
                        if object.isHighlight {
                            Label("Highlight", systemImage: "star.fill")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(.thinMaterial, in: Capsule())
                        }
                        if !object.galleryNumber.isEmpty {
                            Label("On view, gallery " + object.galleryNumber, systemImage: "mappin.and.ellipse")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(.thinMaterial, in: Capsule())
                        }
                    }
                    Text(object.displayTitle)
                        .font(.system(.largeTitle, design: .serif).weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    if let artist = object.displayArtist {
                        Text(artist)
                            .font(.title3)
                    }
                    if let date = object.displayDate {
                        Text(date)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                ArtworkFacts(object: object)

                if !object.tagTerms.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(object.tagTerms, id: \.self) { term in
                            Text(term)
                                .font(.callout)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.accentColor.opacity(0.15), in: Capsule())
                        }
                    }
                }

                HStack(spacing: 20) {
                    if let url = object.webURL {
                        Link(destination: url) {
                            Label("View on metmuseum.org", systemImage: "safari")
                        }
                    }
                    if let url = object.imageURL(.original) {
                        Link(destination: url) {
                            Label("Full-size image", systemImage: "arrow.up.left.and.arrow.down.right")
                        }
                    }
                    if !object.additionalImages.isEmpty {
                        Text("\(object.additionalImages.count) more views on metmuseum.org")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.callout)

                MetOpenAccessCredit()
            }
            .padding(24)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
    }
}
