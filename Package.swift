// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "SpankMac",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "SpankMac",
            path: "Sources",
            resources: [
                .copy("../Resources/spank")
            ]
        )
    ]
)
