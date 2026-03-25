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
        .systemLibrary(
            name: "Clibgit2System",
            pkgConfig: "libgit2",
            providers: [
                .brew(["libgit2", "pkgconf"]),
                .apt(["libgit2-dev", "pkg-config"])
            ]
        ),
        .target(
            name: "Libgit2Bindings",
            dependencies: [
                .target(name: "Clibgit2System", condition: .when(platforms: [.macOS])),
                .target(name: "Clibgit2Binary", condition: .when(platforms: [.iOS, .visionOS]))
            ],
            linkerSettings: [
                .linkedFramework("CoreFoundation", .when(platforms: [.iOS, .visionOS])),
                .linkedFramework("Security", .when(platforms: [.iOS, .visionOS])),
                .linkedLibrary("iconv", .when(platforms: [.iOS, .visionOS]))
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
