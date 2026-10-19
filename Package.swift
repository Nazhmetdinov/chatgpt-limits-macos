// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ChatGPTLimits",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "ChatGPTLimits", targets: ["ChatGPTLimits"])],
    targets: [
        .target(name: "LimitsCore"),
        .executableTarget(name: "ChatGPTLimits", dependencies: ["LimitsCore"]),
        .executableTarget(name: "LimitsChecks", dependencies: ["LimitsCore"], path: "Tests/LimitsCoreTests")
    ],
    swiftLanguageModes: [.v5]
)
