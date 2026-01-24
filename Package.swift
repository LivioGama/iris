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
    dependencies: [
        .package(url: "https://github.com/apple/swift-atomics.git", from: "1.2.0"),
        .package(url: "https://github.com/google/generative-ai-swift.git", from: "0.5.4")
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

        // C bridge for Rust gaze library
        .systemLibrary(
            name: "CIrisGaze",
            path: "IRISGaze/Sources/Bridge"
        ),

        // Gaze module: Gaze tracking, Rust integration
        .target(
            name: "IRISGaze",
            dependencies: [
                "IRISCore",
                "IRISVision",
                "CIrisGaze",
                .product(name: "Atomics", package: "swift-atomics")
            ],
            path: "IRISGaze/Sources",
            exclude: ["Bridge"],
            linkerSettings: [
                .unsafeFlags(["-L", "libs"]),
                .linkedLibrary("iris_gaze"),
                // Link OpenCV (required by Rust library)
                .unsafeFlags(["-L", "/opt/homebrew/opt/opencv/lib"]),
                .linkedLibrary("opencv_core"),
                .linkedLibrary("opencv_videoio"),
                .linkedLibrary("opencv_imgproc"),
                .linkedLibrary("opencv_objdetect"),
                .linkedLibrary("opencv_dnn"),
                .linkedLibrary("opencv_face"),
                .linkedFramework("Accelerate"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("CoreVideo"),
            ]
        ),

        // Network module: Gemini API, conversation management
        .target(
            name: "IRISNetwork",
            dependencies: [
                "IRISCore",
                "IRISVision",
                .product(name: "GoogleGenerativeAI", package: "generative-ai-swift")
            ],
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
