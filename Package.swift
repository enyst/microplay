// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "MacClient",
    products: [
        .library(
            name: "MacClient",
            targets: ["MacClient"]),
    ],
    dependencies: [
        .package(url: "https://github.com/socketio/socket.io-client-swift.git", from: "16.1.1"),
    ],
    targets: [
        .target(
            name: "MacClient",
            dependencies: [
                .product(name: "SocketIO", package: "socket.io-client-swift")
            ],
            path: "MacClient/Sources/MacClient",
            exclude: ["SwiftUI_Files"]),
        .testTarget(
            name: "MacClientTests",
            dependencies: ["MacClient"],
            path: "Tests/MacClientTests",
            exclude: ["SwiftUI_Tests"]),
    ]
)