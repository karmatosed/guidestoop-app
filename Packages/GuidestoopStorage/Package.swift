// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GuidestoopStorage",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "GuidestoopStorage", targets: ["GuidestoopStorage"]),
    ],
    dependencies: [
        .package(path: "../GuidestoopCore"),
    ],
    targets: [
        .target(
            name: "GuidestoopStorage",
            dependencies: ["GuidestoopCore"]
        ),
        .testTarget(
            name: "GuidestoopStorageTests",
            dependencies: ["GuidestoopStorage"]
        ),
    ]
)
