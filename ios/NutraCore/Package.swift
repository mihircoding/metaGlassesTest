// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "NutraCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "NutraCore", targets: ["NutraCore"])
    ],
    targets: [
        .target(name: "NutraCore"),
        .testTarget(name: "NutraCoreTests", dependencies: ["NutraCore"])
    ]
)
