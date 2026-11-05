import AppKit

final class SettingsWindowController: NSWindowController {
    private unowned let appDelegate: AppDelegate
    private let listDocument = FlippedView()
    private let listScroll = NSScrollView()
    private let pathField = NSTextField()
    private let statusLabel = NSTextField(labelWithString: "")
    private let launchCheckbox = NSButton(checkboxWithTitle: "登录时启动", target: nil, action: nil)
    private let addFinderButton = NSButton(title: "添加访达", target: nil, action: nil)

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 470),
                              styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "ShortcutKey 设置"
        window.collectionBehavior.insert(.moveToActiveSpace)
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildUI()
        refresh()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    private func buildUI() {
        guard let content = window?.contentView else { return }
        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 14
        root.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            root.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            root.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            root.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20)
        ])

        let intro = NSTextField(labelWithString: "按 ⌥ + 键切换应用；应用已在最前面时再次按键会隐藏它。")
        root.addArrangedSubview(intro)

        let header = horizontal()
        let title = NSTextField(labelWithString: "快捷键")
        title.font = .boldSystemFont(ofSize: 13)
        header.addArrangedSubview(title)
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        header.addArrangedSubview(spacer)
        addFinderButton.target = self
        addFinderButton.action = #selector(addFinder)
        header.addArrangedSubview(addFinderButton)
        let add = NSButton(title: "添加应用…", target: self, action: #selector(addApplication))
        header.addArrangedSubview(add)
        root.addArrangedSubview(header)
        header.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true

        listScroll.hasVerticalScroller = true
        listScroll.drawsBackground = false
        listDocument.frame = NSRect(x: 0, y: 0, width: 600, height: 1)
        listScroll.documentView = listDocument
        root.addArrangedSubview(listScroll)
        listScroll.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        listScroll.setContentHuggingPriority(.defaultLow, for: .vertical)

        let pathTitle = NSTextField(labelWithString: "配置文件路径")
        pathTitle.font = .boldSystemFont(ofSize: 13)
        root.addArrangedSubview(pathTitle)
        let pathRow = horizontal()
        pathField.placeholderString = "~/.config/shortcut-key/config.json"
        pathField.target = self
        pathField.action = #selector(applyPath)
        pathRow.addArrangedSubview(pathField)
        let apply = NSButton(title: "应用路径", target: self, action: #selector(applyPath))
        pathRow.addArrangedSubview(apply)
        root.addArrangedSubview(pathRow)
        pathRow.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        pathField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let footer = horizontal()
        launchCheckbox.target = self
        launchCheckbox.action = #selector(changeLaunchAtLogin)
        footer.addArrangedSubview(launchCheckbox)
        let footerSpacer = NSView()
        footerSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        footer.addArrangedSubview(footerSpacer)
        let reload = NSButton(title: "重新加载配置", target: self, action: #selector(reloadConfig))
        footer.addArrangedSubview(reload)
        root.addArrangedSubview(footer)
        footer.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true

        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.maximumNumberOfLines = 2
        root.addArrangedSubview(statusLabel)
        statusLabel.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
    }

    private func horizontal() -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        return stack
    }

    func refresh() {
        listDocument.subviews.forEach { $0.removeFromSuperview() }
        let bindings = appDelegate.config.configuration.bindings
        addFinderButton.isHidden = bindings.contains { $0.bundleID == "com.apple.finder" }
        if bindings.isEmpty {
            let empty = NSTextField(labelWithString: "尚未添加应用")
            empty.textColor = .secondaryLabelColor
            empty.frame = NSRect(x: 0, y: 8, width: 580, height: 24)
            listDocument.addSubview(empty)
        }
        for (index, binding) in bindings.enumerated() {
            let row = makeRow(binding)
            row.frame = NSRect(x: 0, y: CGFloat(index) * 40, width: 580, height: 34)
            listDocument.addSubview(row)
        }
        listDocument.frame = NSRect(x: 0, y: 0, width: 600, height: max(40, CGFloat(bindings.count) * 40))
        listScroll.contentView.scroll(to: .zero)
        listScroll.reflectScrolledClipView(listScroll.contentView)
        pathField.stringValue = appDelegate.config.displayPath
        refreshStatus()
    }

    func refreshStatus() {
        statusLabel.stringValue = appDelegate.statusMessage
        launchCheckbox.state = appDelegate.launchAtLogin ? .on : .off
    }

    private func makeRow(_ binding: Binding) -> NSView {
        let row = horizontal()
        let appURL = URL(fileURLWithPath: binding.appPath)
        let icon = NSImageView(image: NSWorkspace.shared.icon(forFile: appURL.path))
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.widthAnchor.constraint(equalToConstant: 25).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 25).isActive = true
        row.addArrangedSubview(icon)

        let appName = binding.bundleID == "com.apple.finder"
            ? "访达" : appURL.deletingPathExtension().lastPathComponent
        let name = NSTextField(labelWithString: appName)
        name.lineBreakMode = .byTruncatingMiddle
        name.toolTip = binding.bundleID
        row.addArrangedSubview(name)
        name.widthAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true
        name.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(spacer)

        let recorder = ShortcutRecorder(title: binding.keyName.map { "⌥\($0)" } ?? "录入快捷键", target: nil, action: nil)
        recorder.target = recorder
        recorder.action = #selector(ShortcutRecorder.startRecordingAction)
        recorder.widthAnchor.constraint(greaterThanOrEqualToConstant: 130).isActive = true
        recorder.onBegin = { [weak self] in self?.appDelegate.beginRecording() }
        recorder.onFinish = { [weak self] code, keyName in
            guard let self else { return }
            if let code, let keyName {
                var updated = self.appDelegate.config.configuration
                guard let index = updated.bindings.firstIndex(where: { $0.id == binding.id }) else { return }
                updated.bindings[index].keyCode = code
                updated.bindings[index].keyName = keyName
                DispatchQueue.main.async { self.appDelegate.save(updated) }
            } else {
                DispatchQueue.main.async { self.appDelegate.endRecording(); self.refresh() }
            }
        }
        row.addArrangedSubview(recorder)

        let remove = NSButton(title: "删除", target: nil, action: nil)
        remove.target = self
        remove.action = #selector(removeBinding(_:))
        remove.identifier = NSUserInterfaceItemIdentifier(binding.id.uuidString)
        row.addArrangedSubview(remove)
        return row
    }

    @objc private func addApplication() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "添加"
        panel.beginSheetModal(for: window!) { [weak self] result in
            guard result == .OK, let url = panel.url, let bundle = Bundle(url: url),
                  let bundleID = bundle.bundleIdentifier, let self else { return }
            var updated = self.appDelegate.config.configuration
            updated.bindings.append(Binding(bundleID: bundleID, appPath: url.path))
            self.appDelegate.save(updated)
        }
    }

    @objc private func addFinder() {
        var updated = appDelegate.config.configuration
        guard !updated.bindings.contains(where: { $0.bundleID == "com.apple.finder" }) else { return }
        updated.bindings.insert(.finder, at: 0)
        appDelegate.save(updated)
    }

    @objc private func removeBinding(_ sender: NSButton) {
        guard let rawID = sender.identifier?.rawValue, let id = UUID(uuidString: rawID) else { return }
        var updated = appDelegate.config.configuration
        updated.bindings.removeAll { $0.id == id }
        appDelegate.save(updated)
    }

    @objc private func applyPath() { appDelegate.changeConfigPath(pathField.stringValue) }
    @objc private func changeLaunchAtLogin() { appDelegate.setLaunchAtLogin(launchCheckbox.state == .on) }
    @objc private func reloadConfig() { appDelegate.reloadConfiguration(); refresh() }
}

private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}
