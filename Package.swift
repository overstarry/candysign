// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "CandySign",
  defaultLocalization: "en",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "CandySign", targets: ["CandySignApp"]),
    .executable(name: "CandySignProbe", targets: ["CandySignProbe"]),
  ],
  targets: [
    .target(name: "CandySignCore", resources: [.process("Resources")]),
    .executableTarget(name: "CandySignProbe", dependencies: ["CandySignCore"]),
    .executableTarget(
      name: "CandySignApp",
      dependencies: ["CandySignCore"],
      swiftSettings: [
        .defaultIsolation(MainActor.self),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
      ]
    ),
    .testTarget(name: "CandySignCoreTests", dependencies: ["CandySignCore"]),
    .testTarget(name: "CandySignAppTests", dependencies: ["CandySignApp"]),
  ]
)
