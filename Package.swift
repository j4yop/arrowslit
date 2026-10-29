// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Arrowslit",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Arrowslit", targets: ["Arrowslit"]),
        .library(name: "ArrowslitMedia", type: .dynamic, targets: ["ArrowslitMedia"]),
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
        .target(
            name: "ArrowslitMedia",
            path: "Sources/ArrowslitMedia",
            publicHeadersPath: "include",
            linkerSettings: [.linkedFramework("Foundation")]
        ),
        .testTarget(
            name: "ArrowslitKitTests",
            dependencies: ["ArrowslitKit"],
            path: "Tests/ArrowslitKitTests"
        ),
    ]
)
