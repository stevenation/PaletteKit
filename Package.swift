// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PaletteKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "PaletteKit", targets: ["PaletteKit"]),
    ],
    targets: [
        .target(name: "PaletteKit"),
        .testTarget(
            name: "PaletteKitTests",
            dependencies: ["PaletteKit"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
