// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GuidestoopCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "GuidestoopCore", targets: ["GuidestoopCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.1.0"),
    ],
    targets: [
        .target(
            name: "GuidestoopCore",
            dependencies: ["Yams"]
        ),
        .testTarget(
            name: "GuidestoopCoreTests",
            dependencies: ["GuidestoopCore"]
        ),
    ]
)
