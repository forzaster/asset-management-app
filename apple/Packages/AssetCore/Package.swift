// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AssetCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "AssetCore", targets: ["AssetCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
        .package(url: "https://github.com/dehesa/CodableCSV.git", from: "0.6.7"),
        .package(url: "https://github.com/marmelroy/Zip.git", from: "2.1.2"),
    ],
    targets: [
        .target(
            name: "AssetCore",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "CodableCSV", package: "CodableCSV"),
                .product(name: "Zip", package: "Zip"),
            ]
        ),
        .testTarget(
            name: "AssetCoreTests",
            dependencies: ["AssetCore"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
