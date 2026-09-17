// swift-tools-version: 6.0
import Foundation
import PackageDescription

// SwiftUI's @State/@Environment are macros whose plugin ships inside Xcode, not
// the Command Line Tools. Set VOLTGUARD_CORE_ONLY=1 to build and test the
// non-UI targets on a machine without Xcode.
let coreOnly = ProcessInfo.processInfo.environment["VOLTGUARD_CORE_ONLY"] == "1"

let appProducts: [Product] = coreOnly ? [] : [
    .executable(name: "VoltGuard", targets: ["voltguard"])
]

let appTargets: [Target] = coreOnly ? [] : [
    .target(
        name: "VoltGuardUI",
        dependencies: ["VoltGuardCore", "VoltGuardStore", "VoltGuardPlatform", "VoltGuardIcon"],
        swiftSettings: [.swiftLanguageMode(.v5)]
    ),
    .executableTarget(
        name: "voltguard",
        dependencies: ["VoltGuardCore", "VoltGuardStore", "VoltGuardPlatform", "VoltGuardUI"],
        swiftSettings: [.swiftLanguageMode(.v5)]
    ),
]

let package = Package(
    name: "VoltGuard",
    platforms: [.macOS(.v14)],
    products: appProducts + [
        .library(name: "VoltGuardCore", targets: ["VoltGuardCore"]),
        .executable(name: "voltguard-selftest", targets: ["voltguard-selftest"]),
        .executable(name: "voltguard-iconforge", targets: ["voltguard-iconforge"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.4")
    ],
    targets: appTargets + [
        .target(
            name: "VoltGuardCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "VoltGuardStore",
            dependencies: ["VoltGuardCore"],
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .target(
            name: "VoltGuardPlatform",
            dependencies: [
                "VoltGuardCore",
                "VoltGuardStore",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(
            name: "VoltGuardIcon",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "voltguard-iconforge",
            dependencies: ["VoltGuardIcon"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "voltguard-selftest",
            dependencies: ["VoltGuardCore", "VoltGuardStore", "VoltGuardPlatform"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "VoltGuardCoreTests",
            dependencies: ["VoltGuardCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "VoltGuardStoreTests",
            dependencies: ["VoltGuardStore", "VoltGuardCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "VoltGuardPlatformTests",
            dependencies: ["VoltGuardPlatform", "VoltGuardCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
