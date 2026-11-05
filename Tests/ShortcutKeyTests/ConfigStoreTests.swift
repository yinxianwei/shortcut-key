import Foundation
import XCTest
@testable import ShortcutKey

final class ConfigStoreTests: XCTestCase {
    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("config.json")
    }

    func testNewConfigurationStartsWithFinder() throws {
        let file = temporaryURL()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let store = ConfigStore(urlOverride: file)
        try store.load()
        XCTAssertEqual(store.configuration.version, 2)
        XCTAssertEqual(store.configuration.bindings.map(\.bundleID), ["com.apple.finder"])
    }

    func testExistingConfigurationGainsFinderWithoutLosingBindings() throws {
        let file = temporaryURL()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let old = """
        {"version":1,"bindings":[{"id":"66FDBC40-57C6-4811-B7FF-E443ACE55773","bundleID":"com.microsoft.VSCode","appPath":"/Applications/Visual Studio Code.app","keyCode":7,"keyName":"X"}]}
        """
        try Data(old.utf8).write(to: file)

        let store = ConfigStore(urlOverride: file)
        try store.load()
        XCTAssertEqual(store.configuration.version, 2)
        XCTAssertEqual(store.configuration.bindings.map(\.bundleID), ["com.apple.finder", "com.microsoft.VSCode"])
        XCTAssertNil(store.configuration.bindings[0].keyCode)
        XCTAssertEqual(store.configuration.bindings[1].keyCode, 7)

        var edited = store.configuration
        edited.bindings.removeFirst()
        try store.replace(edited)
        try store.load()
        XCTAssertEqual(store.configuration.bindings.map(\.bundleID), ["com.microsoft.VSCode"])
    }
}
