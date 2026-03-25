// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-git",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .visionOS(.v2)
    ],
    products: [
        .library(
            name: "SwiftGit",
            targets: ["SwiftGit"]
        )
    ],
    targets: [
        .binaryTarget(
            name: "Clibgit2Binary",
            path: "Vendor/Clibgit2Binary.xcframework"
        ),
        .target(
            name: "Libgit2Bindings",
            dependencies: [
                .target(name: "Clibgit2Binary", condition: .when(platforms: [.macOS, .iOS, .visionOS]))
            ],
            linkerSettings: [
                .linkedFramework("CoreFoundation", .when(platforms: [.macOS, .iOS, .visionOS])),
                .linkedFramework("Security", .when(platforms: [.macOS, .iOS, .visionOS])),
                .linkedLibrary("iconv", .when(platforms: [.macOS, .iOS, .visionOS]))
            ]
        ),
        .target(
            name: "SwiftGit",
            dependencies: ["Libgit2Bindings"]
        ),
        .testTarget(
            name: "SwiftGitTests",
            dependencies: ["SwiftGit"]
        )
    ]
)
