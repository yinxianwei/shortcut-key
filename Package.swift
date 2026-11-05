// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ShortcutKey",
    platforms: [.macOS("26.0")],
    products: [.executable(name: "ShortcutKey", targets: ["ShortcutKey"])],
    targets: [
        .executableTarget(name: "ShortcutKey", path: "Sources/ShortcutKey"),
        .testTarget(name: "ShortcutKeyTests", dependencies: ["ShortcutKey"])
    ]
)
