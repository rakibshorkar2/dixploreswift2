// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DirXplore",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v18)
    ],
    dependencies: [
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.7.0"),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.29.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.1.0"),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "4.2.2"),
    ],
    targets: [
        .target(
            name: "DirXplore",
            dependencies: [
                "SwiftSoup",
                "GRDB",
                "Yams",
                "KeychainAccess",
            ],
            path: ".",
            exclude: [
                "project.yml",
                "Package.swift",
                ".github/",
                "**/*.md",
                "Tests/",
                "LiveActivity/",
                "Widgets/",
            ],
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "DirXploreTests",
            dependencies: ["DirXplore"],
            path: "Tests"
        ),
    ]
)
