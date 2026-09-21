// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AutoClick",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AutoClick", targets: ["AutoClick"])
    ],
    targets: [
        .executableTarget(
            name: "AutoClick",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon"),
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("Vision"),
                .linkedFramework("ServiceManagement")
            ]
        ),
        .testTarget(
            name: "AutoClickTests",
            dependencies: ["AutoClick"]
        )
    ]
)
