// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "tab-switcher",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "tab-switcher",
            dependencies: [],
            path: "Sources/tab-switcher",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny")
            ]
        )
    ]
)
