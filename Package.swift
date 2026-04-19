// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "BenfordCheck",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .executable(
            name: "BenfordCheck",
            targets: ["BenfordCheck"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/CoreOffice/CoreXLSX.git", from: "0.14.1"),
        .package(url: "https://github.com/dehesa/CodableCSV.git", from: "0.6.7"),
    ],
    targets: [
        .executableTarget(
            name: "BenfordCheck",
            dependencies: [
                "CoreXLSX",
                "CodableCSV",
            ]
        ),
        .testTarget(
            name: "BenfordCheckTests",
            dependencies: ["BenfordCheck"],
            resources: [
                .process("Fixtures"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
