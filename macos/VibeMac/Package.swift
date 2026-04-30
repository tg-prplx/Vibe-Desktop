// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "VibeMac",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "VibeMac", targets: ["VibeMac"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "VibeMac",
            dependencies: []
        )
    ]
)
