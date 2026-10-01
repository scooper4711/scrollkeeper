// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PaizoLibraryManager",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PaizoLibraryKit", targets: ["PaizoLibraryKit"]),
        .library(name: "PaizoLibraryUI", targets: ["PaizoLibraryUI"]),
        .executable(name: "PaizoLibraryManager", targets: ["PaizoLibraryManager"])
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.19")
    ],
    targets: [
        .target(
            name: "PaizoLibraryKit",
            dependencies: [.product(name: "ZIPFoundation", package: "ZIPFoundation")]
        ),
        .target(name: "PaizoLibraryUI", dependencies: ["PaizoLibraryKit"]),
        .executableTarget(name: "PaizoLibraryManager", dependencies: ["PaizoLibraryUI"]),
        .testTarget(name: "PaizoLibraryKitTests", dependencies: ["PaizoLibraryKit"])
    ]
)
