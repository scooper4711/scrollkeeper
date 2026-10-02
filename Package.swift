// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PaizoLibraryManager",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PaizoLibraryKit", targets: ["PaizoLibraryKit"]),
        .executable(name: "PaizoLibraryManager", targets: ["PaizoLibraryManager"])
    ],
    targets: [
        .target(name: "PaizoLibraryKit"),
        .executableTarget(name: "PaizoLibraryManager", dependencies: ["PaizoLibraryKit"]),
        .testTarget(name: "PaizoLibraryKitTests", dependencies: ["PaizoLibraryKit"])
    ]
)
