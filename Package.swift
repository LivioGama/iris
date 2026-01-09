// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "IRIS",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "IRIS", targets: ["IRIS"])
    ],
    targets: [
        .executableTarget(
            name: "IRIS",
            path: "IRIS"
        )
    ]
)
