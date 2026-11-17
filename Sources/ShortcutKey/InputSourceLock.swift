import AppKit
import Carbon

struct InputSourceOption: Equatable {
    let id: String
    let name: String
}

@MainActor final class InputSourceLock {
    private(set) var configuration = InputLockConfiguration()
    var onStatusChanged: (() -> Void)?

    private var sourceObserver: NSObjectProtocol?
    private var enabledSourcesObserver: NSObjectProtocol?
    private var appObserver: NSObjectProtocol?
    private var pendingCheck: Task<Void, Never>?
    private var lastAttempt: Date = .distantPast

    init() {
        let center = DistributedNotificationCenter.default()
        sourceObserver = center.addObserver(
            forName: Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.scheduleCheck() }
        }
        enabledSourcesObserver = center.addObserver(
            forName: Notification.Name(kTISNotifyEnabledKeyboardInputSourcesChanged as String),
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.scheduleCheck() }
        }
        appObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.scheduleCheck() }
        }
    }

    isolated deinit {
        if let sourceObserver { DistributedNotificationCenter.default().removeObserver(sourceObserver) }
        if let enabledSourcesObserver { DistributedNotificationCenter.default().removeObserver(enabledSourcesObserver) }
        if let appObserver { NSWorkspace.shared.notificationCenter.removeObserver(appObserver) }
        pendingCheck?.cancel()
    }

    func update(_ value: InputLockConfiguration) {
        configuration = value
        pendingCheck?.cancel()
        if value.enabled { scheduleCheck() }
        onStatusChanged?()
    }

    var statusMessage: String {
        guard configuration.enabled else { return "锁定已暂停" }
        guard let id = configuration.sourceID,
              let target = Self.availableSources().first(where: { $0.id == id }) else {
            return "所选输入法不可用，请在系统设置中启用后刷新列表"
        }
        if IsSecureEventInputEnabled() { return "安全输入期间暂停切换" }
        return Self.currentSourceID() == id ? "已锁定：\(target.name)" : "等待切换到：\(target.name)"
    }

    func scheduleCheck() {
        guard configuration.enabled else { return }
        pendingCheck?.cancel()
        pendingCheck = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            self?.enforce()
        }
    }

    private func enforce() {
        guard configuration.enabled, let id = configuration.sourceID,
              !id.isEmpty, !IsSecureEventInputEnabled(),
              Self.currentSourceID() != id else {
            onStatusChanged?()
            return
        }
        let now = Date()
        guard now.timeIntervalSince(lastAttempt) >= 0.5 else { return }
        lastAttempt = now
        let filter = [kTISPropertyInputSourceID as String: id] as CFDictionary
        guard let list = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource],
              let source = list.first,
              Self.isSelectCapable(source) else {
            onStatusChanged?()
            return
        }
        _ = TISSelectInputSource(source)
        onStatusChanged?()
    }

    static func availableSources() -> [InputSourceOption] {
        guard let list = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else {
            return []
        }
        return list.compactMap { source in
            guard stringProperty(source, kTISPropertyInputSourceCategory) == kTISCategoryKeyboardInputSource as String,
                  isSelectCapable(source),
                  let id = stringProperty(source, kTISPropertyInputSourceID),
                  let name = stringProperty(source, kTISPropertyLocalizedName) else { return nil }
            return InputSourceOption(id: id, name: name)
        }
    }

    static func currentSourceID() -> String? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return nil }
        return stringProperty(source, kTISPropertyInputSourceID)
    }

    private static func stringProperty(_ source: TISInputSource, _ key: CFString) -> String? {
        guard let pointer = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
    }

    private static func isSelectCapable(_ source: TISInputSource) -> Bool {
        guard let pointer = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsSelectCapable) else { return false }
        return CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(pointer).takeUnretainedValue())
    }
}
