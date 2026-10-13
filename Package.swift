// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MetMuseumKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "MetMuseumKit", targets: ["MetMuseumKit"]),
        .library(name: "MetMuseumUI", targets: ["MetMuseumUI"]),
    ],
    targets: [
        .target(name: "MetMuseumKit"),
        .target(name: "MetMuseumUI", dependencies: ["MetMuseumKit"]),
        .testTarget(
            name: "MetMuseumKitTests",
            dependencies: ["MetMuseumKit"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
