// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PhotoExodus",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PhotoExodusCore", targets: ["PhotoExodusCore"]),
    ],
    targets: [
        .target(
            name: "PhotoExodusCore",
            path: "Sources/PhotoExodusCore"
        ),
        .testTarget(
            name: "PhotoExodusCoreTests",
            dependencies: ["PhotoExodusCore"],
            path: "Tests/PhotoExodusCoreTests"
        ),
    ]
)
