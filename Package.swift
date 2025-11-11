// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SwiftDisc",
    platforms: [
        .iOS(.v14),
        .macOS(.v11),
        .tvOS(.v14),
        .watchOS(.v7)
    ],
    products: [
        .library(name: "SwiftDisc", targets: ["SwiftDisc"])
    ],
    targets: [
        .target(name: "SwiftDisc"),
        .testTarget(name: "SwiftDiscTests", dependencies: ["SwiftDisc"])
    ]
)
