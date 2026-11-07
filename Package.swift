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
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.19"),
        // Moves to the release with TablesideShared once scooper4711/tabletop-kit#28 is merged.
        .package(url: "https://github.com/scooper4711/tabletop-kit.git", branch: "feat/tableside-shared")
    ],
    targets: [
        .target(
            name: "ScrollkeeperKit",
            dependencies: [
                .product(name: "ZIPFoundation", package: "ZIPFoundation"),
                .product(name: "TablesideShared", package: "tabletop-kit")
            ]
        ),
        .target(name: "ScrollkeeperUI", dependencies: ["ScrollkeeperKit"]),
        .executableTarget(name: "Scrollkeeper", dependencies: ["ScrollkeeperUI"]),
        .testTarget(
            name: "ScrollkeeperKitTests",
            dependencies: ["ScrollkeeperKit", .product(name: "TablesideShared", package: "tabletop-kit")]
        )
    ]
)
