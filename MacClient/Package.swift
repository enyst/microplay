// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "MacClient",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "MacClient", targets: ["MacClient"])
    ],
    dependencies: [
        .package(url: "https://github.com/socketio/socket.io-client-swift.git", from: "16.0.0")
    ],
    targets: [
        .executableTarget(
            name: "MacClient",
            dependencies: [
                .product(name: "SocketIO", package: "socket.io-client-swift")
            ],
            path: "MacClient"
        ),
        .testTarget(
            name: "MacClientTests",
            dependencies: ["MacClient"],
            path: "MacClientTests"
        )
    ]
)