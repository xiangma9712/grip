// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "grip",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "grip", targets: ["grip"])
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.1.3"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0")
    ],
    targets: [
        .executableTarget(
            name: "grip",
            dependencies: [
                .product(name: "Yams", package: "Yams"),
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(
            name: "gripTests",
            dependencies: ["grip"]
        )
    ]
)
