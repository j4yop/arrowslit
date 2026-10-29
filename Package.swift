// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Arrowslit",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Arrowslit", targets: ["Arrowslit"]),
    ],
    targets: [
        .executableTarget(
            name: "Arrowslit",
            dependencies: ["ArrowslitKit"],
            path: "Sources/Arrowslit"
        ),
        .target(
            name: "ArrowslitKit",
            path: "Sources/ArrowslitKit"
        ),
        .testTarget(
            name: "ArrowslitKitTests",
            dependencies: ["ArrowslitKit"],
            path: "Tests/ArrowslitKitTests"
        ),
    ]
)
