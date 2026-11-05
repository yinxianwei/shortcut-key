import AppKit
import ServiceManagement

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    let config = ConfigStore()
    let hotkeys = HotkeyManager()
    private var statusItem: NSStatusItem!
    private var settings: SettingsWindowController?
    private(set) var statusMessage = ""

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let iconURL = Bundle.main.url(forResource: "AppIconCompact", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = icon
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = MenuBarIcon.make()
        buildMenu()
        reloadConfiguration()
        if config.configuration.bindings.isEmpty { openSettings() }
    }

    private func buildMenu() {
        let menu = NSMenu()
        let settingsItem = NSMenuItem(title: "设置…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        let reloadItem = NSMenuItem(title: "重新加载配置", action: #selector(reloadFromMenu), keyEquivalent: "")
        reloadItem.target = self
        menu.addItem(reloadItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "退出 ShortcutKey", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    @objc private func openSettings() {
        if settings == nil { settings = SettingsWindowController(appDelegate: self) }
        // Menu actions run while the status menu is still closing. Raise on the
        // next run-loop turn so the menu cannot immediately take focus back.
        DispatchQueue.main.async { [weak self] in
            guard let self, let settings = self.settings, let window = settings.window else { return }
            NSApp.unhide(nil)
            NSApp.activate()
            if window.isMiniaturized { window.deminiaturize(nil) }
            settings.showWindow(nil)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
    }

    @objc private func reloadFromMenu() {
        reloadConfiguration()
        settings?.refresh()
    }

    @objc private func quit() { NSApp.terminate(nil) }

    func reloadConfiguration() {
        do {
            try config.load()
            let errors = hotkeys.register(config.configuration)
            statusMessage = errors.isEmpty ? "已加载 \(config.configuration.bindings.count) 条配置" : errors.joined(separator: "；")
        } catch {
            hotkeys.suspend()
            statusMessage = "配置读取失败：\(error.localizedDescription)"
        }
        settings?.refreshStatus()
    }

    func save(_ newValue: Configuration) {
        do {
            try config.replace(newValue)
            let errors = hotkeys.register(newValue)
            statusMessage = errors.isEmpty ? "已保存" : errors.joined(separator: "；")
        } catch {
            _ = hotkeys.register(config.configuration)
            statusMessage = "保存失败：\(error.localizedDescription)"
        }
        settings?.refresh()
    }

    func changeConfigPath(_ path: String) {
        do {
            try config.changePath(path)
            let errors = hotkeys.register(config.configuration)
            statusMessage = errors.isEmpty ? "配置路径已更新" : errors.joined(separator: "；")
        } catch {
            statusMessage = "路径更新失败：\(error.localizedDescription)"
        }
        settings?.refresh()
    }

    func beginRecording() { hotkeys.suspend() }
    func endRecording() {
        let errors = hotkeys.register(config.configuration)
        statusMessage = errors.isEmpty ? "未修改快捷键" : errors.joined(separator: "；")
    }

    var launchAtLogin: Bool { SMAppService.mainApp.status == .enabled }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            statusMessage = SMAppService.mainApp.status == .requiresApproval
                ? "请在系统设置的登录项中允许 ShortcutKey" : "开机启动已更新"
        } catch {
            statusMessage = "开机启动设置失败：\(error.localizedDescription)"
        }
        settings?.refreshStatus()
    }
}
