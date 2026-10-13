import Foundation

/// Which size of a work's image to use.
///
/// The API sends two URLs for the primary image: `primaryImageSmall`, a web rendition about 1,000
/// pixels on its long side, and `primaryImage`, the original file, often several thousand pixels
/// and several megabytes. Use `.small` for grids and lists and `.original` for zooming or printing.
public enum MetImageSize: String, CaseIterable, Sendable {
    /// `primaryImageSmall` (`…/web-large/…`).
    case small
    /// `primaryImage` (`…/original/…`).
    case original
}

/// A rendition folder on images.metmuseum.org. Image URLs look like
/// `https://images.metmuseum.org/CRDImages/ep/original/DP-42549-001.jpg`; the folder before the
/// file name picks the size.
public enum MetImageRendition: String, CaseIterable, Sendable {
    /// About 1,000 pixels on the long side; what `primaryImageSmall` points to.
    case webLarge = "web-large"
    /// The full-size file; what `primaryImage` and `additionalImages` point to.
    case original = "original"

    /// The URL of the same image in this rendition, or `nil` when `url` is not an
    /// images.metmuseum.org URL with a rendition folder.
    public func url(for url: URL) -> URL? {
        guard let host = url.host?.lowercased(), host == MetImageRendition.host else { return nil }
        var components = url.pathComponents
        guard components.count >= 3 else { return nil }
        let folderIndex = components.count - 2
        guard MetImageRendition(rawValue: components[folderIndex]) != nil else { return nil }
        components[folderIndex] = rawValue
        var parts = URLComponents(url: url, resolvingAgainstBaseURL: false)
        parts?.path = "/" + components.dropFirst().joined(separator: "/")
        return parts?.url
    }

    /// The rendition of an images.metmuseum.org URL, or `nil`.
    public init?(of url: URL) {
        let components = url.pathComponents
        guard url.host?.lowercased() == MetImageRendition.host, components.count >= 3 else { return nil }
        self.init(rawValue: components[components.count - 2])
    }

    /// `images.metmuseum.org`, where the API's images live.
    public static let host = "images.metmuseum.org"
}

extension MetObject {
    /// Whether the work is Open Access and has a primary image.
    public var hasPublicDomainImage: Bool {
        isPublicDomain && hasImage
    }

    /// Whether the API sent a primary image.
    public var hasImage: Bool {
        primaryImageSmall.httpURL != nil || primaryImage.httpURL != nil
    }

    /// The primary image in the size you ask for, falling back to the other size when that one is
    /// missing, or `nil` when the work has no image.
    public func imageURL(_ size: MetImageSize = .small) -> URL? {
        let small = primaryImageSmall.httpURL
        let original = primaryImage.httpURL
        switch size {
        case .small:
            return small ?? original.flatMap { MetImageRendition.webLarge.url(for: $0) } ?? original
        case .original:
            return original ?? small.flatMap { MetImageRendition.original.url(for: $0) } ?? small
        }
    }

    /// The primary image's web-sized URL (`primaryImageSmall`).
    public var smallImageURL: URL? { imageURL(.small) }

    /// The primary image's full-size URL (`primaryImage`).
    public var originalImageURL: URL? { imageURL(.original) }

    /// The additional images (other views and details). The API lists the originals; ask for
    /// `.small` to get their web renditions, which are much lighter.
    public func additionalImageURLs(_ size: MetImageSize = .small) -> [URL] {
        additionalImages.compactMap(\.httpURL).map { url in
            switch size {
            case .small: return MetImageRendition.webLarge.url(for: url) ?? url
            case .original: return MetImageRendition.original.url(for: url) ?? url
            }
        }
    }

    /// The primary image followed by the additional images, in one size.
    public func allImageURLs(_ size: MetImageSize = .small) -> [URL] {
        var urls: [URL] = []
        if let primary = imageURL(size) { urls.append(primary) }
        for url in additionalImageURLs(size) where !urls.contains(url) {
            urls.append(url)
        }
        return urls
    }
}

extension Sequence where Element == MetObject {
    /// The Open Access works that have a primary image, in order.
    public func publicDomainWithImages() -> [MetObject] {
        filter(\.hasPublicDomainImage)
    }
}
