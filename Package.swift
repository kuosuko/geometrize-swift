// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Geometrize",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .visionOS(.v1),
        .watchOS(.v8)
    ],
    products: [
        .library(name: "Geometrize", targets: ["Geometrize"])
    ],
    targets: [
        .target(name: "Geometrize"),
        .testTarget(name: "GeometrizeTests", dependencies: ["Geometrize"])
    ]
)
