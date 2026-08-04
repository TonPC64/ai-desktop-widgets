// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CopilotWidget",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "CopilotWidgetCore", targets: ["CopilotWidgetCore"]),
        .executable(name: "CopilotWidgetHost", targets: ["CopilotWidgetHost"])
    ],
    targets: [
        .target(name: "CopilotWidgetCore"),
        .executableTarget(
            name: "CopilotWidgetHost",
            dependencies: ["CopilotWidgetCore"],
            linkerSettings: [
                .linkedFramework("ServiceManagement"),
                .linkedFramework("WidgetKit")
            ]
        ),
        .testTarget(name: "CopilotWidgetCoreTests", dependencies: ["CopilotWidgetCore"])
    ]
)
