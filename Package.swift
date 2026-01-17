// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "IRIS",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "IRIS", targets: ["IRIS"]),
        .library(name: "IRISCore", targets: ["IRISCore"]),
        .library(name: "IRISVision", targets: ["IRISVision"]),
        .library(name: "IRISGaze", targets: ["IRISGaze"]),
        .library(name: "IRISNetwork", targets: ["IRISNetwork"]),
        .library(name: "IRISMedia", targets: ["IRISMedia"])
    ],
    targets: [
        // Core module: Models, protocols, security
        .target(
            name: "IRISCore",
            path: "IRISCore/Sources"
        ),

        // Vision module: Element detection, text recognition
        .target(
            name: "IRISVision",
            dependencies: ["IRISCore"],
            path: "IRISVision/Sources"
        ),

        // Gaze module: Gaze tracking, Python integration
        .target(
            name: "IRISGaze",
            dependencies: ["IRISCore", "IRISVision"],
            path: "IRISGaze/Sources"
        ),

        // Network module: Gemini API, conversation management
        .target(
            name: "IRISNetwork",
            dependencies: ["IRISCore", "IRISVision"],
            path: "IRISNetwork/Sources"
        ),

        // Media module: Audio, camera, speech, screenshots
        .target(
            name: "IRISMedia",
            dependencies: ["IRISCore"],
            path: "IRISMedia/Sources"
        ),

        // Main app: Orchestration only
        .executableTarget(
            name: "IRIS",
            dependencies: [
                "IRISCore",
                "IRISVision",
                "IRISGaze",
                "IRISNetwork",
                "IRISMedia"
            ],
            path: "IRIS"
        ),

        // Tests
        .testTarget(
            name: "IRISCoreTests",
            dependencies: ["IRISCore"],
            path: "Tests/IRISCoreTests"
        ),
        .testTarget(
            name: "IRISNetworkTests",
            dependencies: ["IRISNetwork", "IRISCore"],
            path: "Tests/IRISNetworkTests"
        ),
        .testTarget(
            name: "IRISGazeTests",
            dependencies: ["IRISGaze", "IRISCore", "IRISVision"],
            path: "Tests/IRISGazeTests"
        ),
        .testTarget(
            name: "IRISIntegrationTests",
            dependencies: ["IRISCore", "IRISVision", "IRISGaze", "IRISNetwork", "IRISMedia"],
            path: "Tests/IRISIntegrationTests"
        )
    ]
)
