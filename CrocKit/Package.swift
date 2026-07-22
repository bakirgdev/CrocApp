// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CrocKit",
    platforms: [.iOS("26.0"), .macOS("26.0")],
    products: [
        .library(name: "CrocKit", targets: ["CrocKit"])
    ],
    targets: [
        .binaryTarget(name: "Croc", path: "Croc.xcframework"),
        .target(name: "CrocKit", dependencies: ["Croc"]),
        .executableTarget(name: "crockit-verify", dependencies: ["CrocKit"]),
    ]
)
