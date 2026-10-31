// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RemoteMouseCore",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "RemoteMouseCore",
            targets: ["RemoteMouseCore"]
        )
    ],
    targets: [
        .target(
            name: "RemoteMouseCore",
            dependencies: [],
            path: "Sources/RemoteMouseCore"
        ),
        .testTarget(
            name: "RemoteMouseCoreTests",
            dependencies: ["RemoteMouseCore"],
            path: "Tests/RemoteMouseCoreTests"
        )
    ]
)
