// swift-tools-version: 6.2
import PackageDescription

// Sin Xcode, Swift Testing está dentro de las Command Line Tools y SwiftPM no lo enlaza solo:
// los tests viven en una librería normal y los lanza el ejecutable `sintecla-tests`.
let cltFrameworks = "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
let cltLibs = "/Library/Developer/CommandLineTools/Library/Developer/usr/lib"
let swift5: SwiftSetting = .swiftLanguageMode(.v5)

let package = Package(
  name: "Sintecla",
  platforms: [.macOS("26.0")],
  targets: [
    .target(name: "SinteclaCore", swiftSettings: [swift5]),
    .executableTarget(name: "Sintecla", dependencies: ["SinteclaCore"], swiftSettings: [swift5]),
    .executableTarget(name: "sintecla-eval", dependencies: ["SinteclaCore"], swiftSettings: [swift5]),
    .target(
      name: "SinteclaCoreTests",
      dependencies: ["SinteclaCore"],
      swiftSettings: [swift5, .unsafeFlags(["-F", cltFrameworks])]
    ),
    .executableTarget(
      name: "sintecla-tests",
      dependencies: ["SinteclaCoreTests"],
      swiftSettings: [swift5, .unsafeFlags(["-F", cltFrameworks])],
      linkerSettings: [.unsafeFlags(["-F", cltFrameworks,
                                     "-Xlinker", "-rpath", "-Xlinker", cltFrameworks,
                                     "-Xlinker", "-rpath", "-Xlinker", cltLibs])]
    ),
  ]
)
