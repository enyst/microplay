// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "MacClient",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "MacClient",
            targets: ["MacClient"]),
    ],
    dependencies: [
        .package(url: "https://github.com/socketio/socket.io-client-swift.git", from: "16.0.0"),
    ],
    targets: [
        .target(
            name: "MacClient",
            dependencies: [
                .product(name: "SocketIO", package: "socket.io-client-swift")
            ],
            path: "MacClient"),
        .testTarget(
            name: "MacClientTests",
            dependencies: ["MacClient"],
            path: "Tests/MacClientTests"),
    ]
)