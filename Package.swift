// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "prepared-text-ios",
    // macOS stays enabled only for host-side Core/validation/benchmark tooling.
    // Public UIKit/SwiftUI surfaces are iOS-only.
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
            dependencies: ["PretextCore"]
        ),
        .executableTarget(
            name: "PretextBenchmarks",
            dependencies: ["PretextCore"]
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
