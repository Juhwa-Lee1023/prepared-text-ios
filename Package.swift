// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "prepared-text-ios",
    // macOS stays enabled for host-side Core validation / benchmark tooling and
    // a narrow subset of prepared-layout helpers such as obstacle layout.
    // UI adoption surfaces still remain UIKit-first / SwiftUI-bridge APIs.
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(name: "PretextCore", targets: ["PretextCore"]),
        .library(name: "PretextUIKit", targets: ["PretextUIKit"]),
        .library(name: "PretextSwiftUI", targets: ["PretextSwiftUI"]),
        .executable(name: "PretextValidation", targets: ["PretextValidation"]),
        .executable(name: "PretextBenchmarks", targets: ["PretextBenchmarks"]),
    ],
    targets: [
        .target(
            name: "PretextCore",
            dependencies: []
        ),
        .target(
            name: "PretextUIKit",
            dependencies: ["PretextCore"]
        ),
        .target(
            name: "PretextSwiftUI",
            dependencies: ["PretextCore", "PretextUIKit"]
        ),
        .executableTarget(
            name: "PretextValidation",
            dependencies: ["PretextCore", "PretextUIKit"]
        ),
        .executableTarget(
            name: "PretextBenchmarks",
            dependencies: ["PretextCore", "PretextUIKit"]
        ),
        .testTarget(
            name: "PretextCoreTests",
            dependencies: ["PretextCore"],
            path: "Tests/PretextCoreTests"
        ),
        .testTarget(
            name: "PretextUIKitTests",
            dependencies: ["PretextCore", "PretextUIKit", "PretextSwiftUI"],
            path: "Tests/PretextUIKitTests"
        ),
    ]
)
