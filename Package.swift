// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "Amtrak",
    products: [
        .library(
            name: "Amtrak",
            targets: ["Amtrak"]
        ),
    ],
    targets: [
        .target(
            name: "Amtrak"
        ),
        .testTarget(
            name: "AmtrakTests",
            dependencies: ["Amtrak"],
            resources: [
                .copy("Fixtures")
            ]
        ),
    ]
)
