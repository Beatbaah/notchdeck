// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NotchDeck",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "NotchDeck",
            path: "Sources/NotchDeck"
        )
    ],
    swiftLanguageVersions: [.v5]
)
