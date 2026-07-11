// swift-tools-version: 6.1
import PackageDescription

let package = Package(
  name: "openwith",
  platforms: [
    .macOS(.v15)
  ],
  products: [
    .library(name: "OpenWithCore", targets: ["OpenWithCore"]),
    .library(name: "OpenWithUI", targets: ["OpenWithUI"]),
    .executable(name: "openwith", targets: ["openwith"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
    .package(url: "https://github.com/LebJe/TOMLKit.git", from: "0.6.0"),
  ],
  targets: [
    .target(
      name: "OpenWithCore",
      dependencies: [
        .product(name: "TOMLKit", package: "TOMLKit")
      ]
    ),
    .target(
      name: "OpenWithUI",
      dependencies: ["OpenWithCore"]
    ),
    .executableTarget(
      name: "openwith",
      dependencies: [
        "OpenWithCore",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ]
    ),
    .testTarget(
      name: "OpenWithCoreTests",
      dependencies: ["OpenWithCore"]
    ),
  ]
)
