// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AirnetCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "AirnetCore", targets: ["AirnetCore"])],
    targets: [
        .systemLibrary(name: "CSQLite"),
        .target(name: "AirnetCore", dependencies: ["CSQLite"]),
        .testTarget(name: "AirnetCoreTests", dependencies: ["AirnetCore"])
    ]
)
