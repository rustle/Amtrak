// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Amtrak",
    products: [
        .library(
            name: "Amtrak",
            targets: ["Amtrak"]
        ),
    ],
    traits: [
        .init(
            name: "AsyncHTTPClient",
            description: "Use AsyncHTTPClient instead of URLSession for networking"
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/swift-server/async-http-client.git",
            from: "1.9.0"
        )
    ],
    targets: [
        .target(
            name: "Amtrak",
            dependencies: [
                .product(
                    name: "AsyncHTTPClient",
                    package: "async-http-client",
                    condition: .when(traits: ["AsyncHTTPClient"])
                )
            ]
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
