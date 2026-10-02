// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Scrollkeeper",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "ScrollkeeperKit", targets: ["ScrollkeeperKit"]),
        .library(name: "ScrollkeeperUI", targets: ["ScrollkeeperUI"]),
        .executable(name: "Scrollkeeper", targets: ["Scrollkeeper"])
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.19")
    ],
    targets: [
        .target(
            name: "ScrollkeeperKit",
            dependencies: [.product(name: "ZIPFoundation", package: "ZIPFoundation")]
        ),
        .target(name: "ScrollkeeperUI", dependencies: ["ScrollkeeperKit"]),
        .executableTarget(name: "Scrollkeeper", dependencies: ["ScrollkeeperUI"]),
        .testTarget(name: "ScrollkeeperKitTests", dependencies: ["ScrollkeeperKit"])
    ]
)
