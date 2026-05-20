// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Luma",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Luma", targets: ["AIPet"])
    ],
    targets: [
        .executableTarget(
            name: "AIPet",
            path: "Sources/AIPet",
            resources: [
                .copy("Resources")
            ]
        )
    ]
)
