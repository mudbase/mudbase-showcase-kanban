// swift-tools-version:6.0
import PackageDescription

// This package is deliberately .xcodeproj-free — see README.md "Why SPM, not an .xcodeproj" (same
// rationale as the sibling `mudbase-showcase-social/swift` and `mudbase-showcase-ecommerce/swift`
// ports this app's architecture is ported from). Xcode 14+ opens Package.swift directly and runs
// an `executableTarget` that defines a SwiftUI `App`/`@main` as a real iOS app on a Simulator or
// device. `swift build` from the CLI also succeeds on plain macOS — the platforms list below just
// sets minimum deployment targets; no UIKit-only symbols are used anywhere in this target.
let package = Package(
    name: "MudbaseShowcaseKanban",
    platforms: [
        .iOS(.v16),
        // v14, not v13 — matches the sibling Swift ports' platforms list: a few SwiftUI toolbar
        // placement APIs and `Task.sleep(for:)` need a floor that lines up with iOS 16 even though
        // this secondary macOS target only exists so `swift build` succeeds without an iOS
        // Simulator (see README "Why SPM, not an .xcodeproj").
        .macOS(.v14),
    ],
    products: [
        .executable(
            name: "MudbaseShowcaseKanban",
            targets: ["MudbaseShowcaseKanban"]
        ),
    ],
    dependencies: [
        // Sibling-clone dependency — see README.md "Setup" for the required directory layout and
        // the SwiftPM package-identity-collision rationale (this package's own directory is named
        // `swift`, same as the SDK repo's Swift subdirectory — pointing straight at
        // `mudbase-sdk/swift` would conflate the two package identities). `mudbase-sdk-swift` is a
        // relative symlink already committed at this monorepo's root
        // (`mudbase-showcase-kanban/mudbase-sdk-swift -> ../mudbase-sdk/swift`), the same
        // workaround the ecommerce/social Swift ports established first.
        .package(name: "MudbaseSDK", path: "../mudbase-sdk-swift"),
    ],
    targets: [
        .executableTarget(
            name: "MudbaseShowcaseKanban",
            dependencies: [
                .product(name: "MudbaseSDK", package: "MudbaseSDK"),
            ],
            path: "Sources/MudbaseShowcaseKanban"
        ),
        // Standalone, headless verification against the real, live `cloud.mudbase.dev` project —
        // `@testable import` is the only way for a separate SPM target to reach this app's own
        // internal `Services`/`Networking`/`Models` types. Disabled by default — see
        // `ManualLiveFlowTests.swift` — so a plain `swift test` never makes network calls or
        // writes real documents on its own.
        .testTarget(
            name: "ManualLiveFlowTests",
            dependencies: ["MudbaseShowcaseKanban"],
            path: "Tests/ManualLiveFlowTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
