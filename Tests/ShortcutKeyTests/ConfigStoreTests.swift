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
        XCTAssertNil(store.configuration.windowShortcuts.leftHalf)
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
        XCTAssertNil(store.configuration.windowShortcuts.leftHalf)

        var edited = store.configuration
        edited.bindings.removeFirst()
        try store.replace(edited)
        try store.load()
        XCTAssertEqual(store.configuration.bindings.map(\.bundleID), ["com.microsoft.VSCode"])
    }

    func testWindowShortcutsPersistAndRejectConflicts() throws {
        let file = temporaryURL()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let store = ConfigStore(urlOverride: file)
        try store.load()

        var edited = store.configuration
        edited.bindings[0].keyCode = 7
        edited.bindings[0].keyName = "X"
        edited.windowShortcuts.leftHalf = WindowShortcut(keyCode: 7, keyName: "X", modifiers: ShortcutModifier.command)
        edited.windowShortcuts.rightHalf = WindowShortcut(keyCode: 7, keyName: "X", modifiers: ShortcutModifier.control)
        try store.replace(edited)
        try store.load()
        XCTAssertEqual(store.configuration.windowShortcuts.leftHalf?.modifiers, ShortcutModifier.command)
        XCTAssertEqual(store.configuration.windowShortcuts.rightHalf?.modifiers, ShortcutModifier.control)

        edited.windowShortcuts.maximize = WindowShortcut(keyCode: 7, keyName: "X", modifiers: ShortcutModifier.option)
        XCTAssertThrowsError(try store.replace(edited)) { error in
            guard case ConfigError.duplicateKey = error else { return XCTFail("Expected duplicate shortcut") }
        }
        XCTAssertNil(store.configuration.windowShortcuts.maximize)
    }

    func testVersionTwoConfigurationWithoutWindowShortcutsStillLoads() throws {
        let file = temporaryURL()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(#"{"version":2,"bindings":[]}"#.utf8).write(to: file)

        let store = ConfigStore(urlOverride: file)
        try store.load()
        XCTAssertNil(store.configuration.windowShortcuts.leftHalf)
        XCTAssertNil(store.configuration.windowShortcuts.rightHalf)
        XCTAssertNil(store.configuration.windowShortcuts.maximize)
    }
}
