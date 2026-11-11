// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PropertyRecordsCore",
    platforms: [.macOS(.v14), .iOS("26.0")],
    products: [.library(name: "PropertyCore", targets: ["PropertyCore"])],
    targets: [
        .target(name: "PropertyCore"),
        .testTarget(name: "PropertyCoreTests", dependencies: ["PropertyCore"])
    ]
)
