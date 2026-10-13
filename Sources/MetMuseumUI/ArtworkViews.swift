import SwiftUI
import MetMuseumKit

extension MetArtworkImage where Placeholder == ArtworkPlaceholder {
    /// A work's primary image in the size you ask for, with a quiet placeholder while it loads or
    /// when the work has no image.
    public init(object: MetObject, size: MetImageSize = .small, contentMode: ContentMode = .fill) {
        self.init(url: object.imageURL(size), contentMode: contentMode) {
            ArtworkPlaceholder(hasImage: object.hasImage)
        }
    }

    /// An image URL with the default placeholder.
    public init(url: URL?, contentMode: ContentMode = .fill) {
        self.init(url: url, contentMode: contentMode) {
            ArtworkPlaceholder(hasImage: url != nil)
        }
    }
}

/// A soft gradient with a frame symbol, shown while an image loads, or a crossed-out photo for a
/// work without one.
public struct ArtworkPlaceholder: View {
    private let hasImage: Bool

    public init(hasImage: Bool = true) {
        self.hasImage = hasImage
    }

    public var body: some View {
        LinearGradient(
            colors: [Color.secondary.opacity(0.18), Color.secondary.opacity(0.08)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            Image(systemName: hasImage ? "photo.artframe" : "photo.badge.exclamationmark")
                .font(.title2)
                .foregroundStyle(.tertiary)
        }
        .accessibilityHidden(true)
    }
}

/// A small "Public domain" capsule for Open Access works.
public struct PublicDomainBadge: View {
    public init() {}

    public var body: some View {
        Label("Public domain", systemImage: "checkmark.seal.fill")
            .font(.caption2.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(.thinMaterial, in: Capsule())
            .accessibilityLabel("Public domain, Open Access")
    }
}

/// A work as a tile for grids (image above, title, artist and date below) or as a row for lists.
public struct ArtworkCard: View {
    public enum Style: Sendable {
        /// The image above the caption, for grids.
        case tile
        /// A thumbnail beside the caption, for lists and sidebars.
        case row
    }

    private let object: MetObject
    private let style: Style
    private let showsBadge: Bool

    public init(object: MetObject, style: Style = .tile, showsBadge: Bool = false) {
        self.object = object
        self.style = style
        self.showsBadge = showsBadge
    }

    public var body: some View {
        switch style {
        case .tile: tile
        case .row: row
        }
    }

    private var tile: some View {
        VStack(alignment: .leading, spacing: 8) {
            MetArtworkImage(object: object)
                .aspectRatio(4 / 5, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(alignment: .topLeading) {
                    if showsBadge && object.isPublicDomain {
                        PublicDomainBadge().padding(8)
                    }
                }
            caption
        }
        .accessibilityElement(children: .combine)
    }

    private var row: some View {
        HStack(spacing: 12) {
            MetArtworkImage(object: object)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            caption
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(object.displayTitle)
                .font(.headline)
                .lineLimit(2)
            if let artist = object.displayArtist {
                Text(artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if let date = object.displayDate {
                Text(date)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
    }
}

/// The catalogue facts of a work as label and value rows: artist, date, medium, dimensions,
/// classification, department, credit line, accession number and gallery. Empty fields are left
/// out.
public struct ArtworkFacts: View {
    private let object: MetObject

    public init(object: MetObject) {
        self.object = object
    }

    /// The rows the view shows, in order.
    public static func rows(for object: MetObject) -> [(label: String, value: String)] {
        var rows: [(label: String, value: String)] = []
        func add(_ label: String, _ value: String?) {
            if let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
                rows.append((label, value))
            }
        }
        var artist = object.artistDisplayName
        if !object.artistDisplayBio.isEmpty && !artist.isEmpty {
            artist += " (" + object.artistDisplayBio + ")"
        }
        add("Artist", artist)
        add("Culture", object.culture)
        add("Period", object.period)
        add("Date", object.displayDate)
        add("Place", object.place)
        add("Medium", object.medium)
        add("Dimensions", object.dimensions)
        add("Classification", object.classification)
        add("Department", object.department)
        add("Credit line", object.creditLine)
        add("Accession number", object.accessionNumber)
        add("Gallery", object.galleryNumber.isEmpty ? nil : "Gallery " + object.galleryNumber)
        return rows
    }

    public var body: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 10) {
            ForEach(Array(Self.rows(for: object).enumerated()), id: \.offset) { item in
                GridRow {
                    Text(item.element.label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .gridColumnAlignment(.trailing)
                    Text(item.element.value)
                        .font(.subheadline)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// The required credit for the images: Open Access from The Met, public domain (CC0).
public struct MetOpenAccessCredit: View {
    public init() {}

    public var body: some View {
        Label {
            Text("Images: The Metropolitan Museum of Art, Open Access (public domain, CC0)")
        } icon: {
            Image(systemName: "building.columns")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
