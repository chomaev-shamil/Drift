// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Drift",
    platforms: [.iOS(.v16), .macOS(.v13), .tvOS(.v16), .watchOS(.v9), .visionOS(.v1)],
    products: [
        .library(name: "Drift", targets: ["Drift"])
    ],
    targets: [
        .target(
            name: "Drift",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .testTarget(
            name: "DriftTests",
            dependencies: ["Drift"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
