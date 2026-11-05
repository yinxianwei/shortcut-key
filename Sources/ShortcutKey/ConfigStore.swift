import Foundation

struct Binding: Codable, Identifiable, Equatable {
    var id: UUID
    var bundleID: String
    var appPath: String
    var keyCode: UInt32?
    var keyName: String?

    init(id: UUID = UUID(), bundleID: String, appPath: String, keyCode: UInt32? = nil, keyName: String? = nil) {
        self.id = id
        self.bundleID = bundleID
        self.appPath = appPath
        self.keyCode = keyCode
        self.keyName = keyName
    }

    static var finder: Binding {
        Binding(bundleID: "com.apple.finder", appPath: "/System/Library/CoreServices/Finder.app")
    }

    private enum CodingKeys: String, CodingKey { case id, bundleID, appPath, keyCode, keyName }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        bundleID = try values.decode(String.self, forKey: .bundleID)
        appPath = try values.decode(String.self, forKey: .appPath)
        keyCode = try values.decodeIfPresent(UInt32.self, forKey: .keyCode)
        keyName = try values.decodeIfPresent(String.self, forKey: .keyName)
            ?? keyCode.flatMap { KeyCatalog.name(for: $0) }
    }
}

struct Configuration: Codable {
    var version = 2
    var bindings: [Binding] = [.finder]
    var windowShortcuts = WindowShortcuts()

    private enum CodingKeys: String, CodingKey { case version, bindings, windowShortcuts }

    init() {}

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = try values.decode(Int.self, forKey: .version)
        bindings = try values.decode([Binding].self, forKey: .bindings)
        windowShortcuts = try values.decodeIfPresent(WindowShortcuts.self, forKey: .windowShortcuts) ?? WindowShortcuts()
    }
}

enum WindowAction: String, CaseIterable {
    case leftHalf, rightHalf, maximize

    var title: String {
        switch self {
        case .leftHalf: "当前窗口置于左侧 50%"
        case .rightHalf: "当前窗口置于右侧 50%"
        case .maximize: "当前窗口铺满可用区域"
        }
    }
}

struct WindowShortcut: Codable, Equatable {
    var keyCode: UInt32
    var keyName: String
    var modifiers: UInt32
}

struct WindowShortcuts: Codable {
    var leftHalf: WindowShortcut?
    var rightHalf: WindowShortcut?
    var maximize: WindowShortcut?

    subscript(_ action: WindowAction) -> WindowShortcut? {
        get {
            switch action {
            case .leftHalf: leftHalf
            case .rightHalf: rightHalf
            case .maximize: maximize
            }
        }
        set {
            switch action {
            case .leftHalf: leftHalf = newValue
            case .rightHalf: rightHalf = newValue
            case .maximize: maximize = newValue
            }
        }
    }
}

enum ConfigError: LocalizedError {
    case invalidVersion
    case duplicateKey(String)
    case invalidBinding(String)
    case invalidWindowShortcut(String)

    var errorDescription: String? {
        switch self {
        case .invalidVersion: return "配置版本不受支持。"
        case .duplicateKey(let name): return "快捷键 \(name) 被重复使用。"
        case .invalidBinding(let name): return "应用 \(name) 的配置不完整。"
        case .invalidWindowShortcut(let name): return "窗口快捷键 \(name) 无效。"
        }
    }
}

final class ConfigStore {
    private let pathKey = "customConfigPath"
    private let urlOverride: URL?
    private(set) var configuration = Configuration()

    init(urlOverride: URL? = nil) { self.urlOverride = urlOverride }

    var defaultURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/shortcut-key/config.json")
    }

    var url: URL {
        if let urlOverride { return urlOverride }
        if let path = UserDefaults.standard.string(forKey: pathKey), !path.isEmpty {
            return Self.url(for: path)
        }
        return defaultURL
    }

    var displayPath: String { url.path }

    static func url(for path: String) -> URL {
        let expanded = (path as NSString).expandingTildeInPath
        return URL(fileURLWithPath: expanded).standardizedFileURL
    }

    func load() throws {
        let file = url
        if !FileManager.default.fileExists(atPath: file.path) {
            configuration = Configuration()
            try save()
            return
        }
        let data = try Data(contentsOf: file)
        var decoded = try JSONDecoder().decode(Configuration.self, from: data)
        try validate(decoded)
        if decoded.version == 1 {
            if let finderIndex = decoded.bindings.firstIndex(where: { $0.bundleID == "com.apple.finder" }) {
                let finder = decoded.bindings.remove(at: finderIndex)
                decoded.bindings.insert(finder, at: 0)
            } else {
                decoded.bindings.insert(.finder, at: 0)
            }
            decoded.version = 2
            try validate(decoded)
            let previous = configuration
            configuration = decoded
            do { try save() } catch {
                configuration = previous
                throw error
            }
        } else {
            configuration = decoded
        }
    }

    func replace(_ newValue: Configuration) throws {
        try validate(newValue)
        let previous = configuration
        configuration = newValue
        do { try save() } catch {
            configuration = previous
            throw error
        }
    }

    func changePath(_ path: String) throws {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CocoaError(.fileNoSuchFile) }
        let destination = Self.url(for: trimmed)
        let oldValue = UserDefaults.standard.string(forKey: pathKey)
        let oldConfiguration = configuration
        UserDefaults.standard.set(destination.path == defaultURL.path ? nil : destination.path, forKey: pathKey)
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try load()
            } else {
                try save()
            }
        } catch {
            UserDefaults.standard.set(oldValue, forKey: pathKey)
            configuration = oldConfiguration
            throw error
        }
    }

    private func save() throws {
        let file = url
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(configuration).write(to: file, options: .atomic)
    }

    private func validate(_ value: Configuration) throws {
        guard value.version == 1 || value.version == 2 else { throw ConfigError.invalidVersion }
        var used = Set<String>()
        for binding in value.bindings {
            guard !binding.bundleID.isEmpty, !binding.appPath.isEmpty else {
                throw ConfigError.invalidBinding(binding.bundleID)
            }
            if let keyCode = binding.keyCode {
                guard KeyCatalog.name(for: keyCode) != nil else {
                    throw ConfigError.invalidBinding(binding.bundleID)
                }
                guard used.insert("\(ShortcutModifier.option):\(keyCode)").inserted else {
                    throw ConfigError.duplicateKey("⌥\(binding.keyName ?? KeyCatalog.name(for: keyCode) ?? "")")
                }
            }
        }
        for action in WindowAction.allCases {
            guard let shortcut = value.windowShortcuts[action] else { continue }
            guard KeyCatalog.name(for: shortcut.keyCode) != nil,
                  shortcut.modifiers != 0,
                  shortcut.modifiers & ~ShortcutModifier.all == 0 else {
                throw ConfigError.invalidWindowShortcut(action.title)
            }
            guard used.insert("\(shortcut.modifiers):\(shortcut.keyCode)").inserted else {
                throw ConfigError.duplicateKey("\(ShortcutModifier.symbols(shortcut.modifiers))\(shortcut.keyName)")
            }
        }
    }
}

enum ShortcutModifier {
    static let shift: UInt32 = 1
    static let control: UInt32 = 2
    static let option: UInt32 = 4
    static let command: UInt32 = 8
    static let all = shift | control | option | command

    static func symbols(_ modifiers: UInt32) -> String {
        var result = ""
        if modifiers & control != 0 { result += "⌃" }
        if modifiers & option != 0 { result += "⌥" }
        if modifiers & shift != 0 { result += "⇧" }
        if modifiers & command != 0 { result += "⌘" }
        return result
    }
}
