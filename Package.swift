// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "MacClient",
    products: [
        .library(
            name: "MacClient",
            targets: ["MacClient"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MacClient",
            dependencies: [],
            path: "MacClient/Sources/MacClient",
            exclude: ["SwiftUI_Files"]),
        .testTarget(
            name: "MacClientTests",
            dependencies: ["MacClient"],
            path: "Tests/MacClientTests",
            exclude: ["SwiftUI_Tests"]),
    ]
)