// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "VimOS",
    platforms: [
        .macOS(.v10_13)
    ],
    targets: [
        // Core Logic Library
        .target(
            name: "VimOSCore"
        ),
        // Main Application Executable
        .executableTarget(
            name: "VimOS",
            dependencies: ["VimOSCore"]
        ),
        // Custom Test Runner Executable
        .executableTarget(
            name: "VimOSTestRunner",
            dependencies: ["VimOSCore"],
            path: "Tests/VimOSTests" 
        ),
    ]
)
