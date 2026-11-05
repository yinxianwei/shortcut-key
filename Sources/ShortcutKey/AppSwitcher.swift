import AppKit

final class AppSwitcher {
    func toggle(_ binding: Binding) {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: binding.bundleID)
            .first(where: { !$0.isTerminated })

        if let app = running {
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier {
                _ = app.hide()
            } else {
                if app.isHidden { _ = app.unhide() }
                _ = app.activate(options: [])
            }
            return
        }

        let savedURL = URL(fileURLWithPath: binding.appPath)
        let appURL = FileManager.default.fileExists(atPath: savedURL.path)
            ? savedURL : NSWorkspace.shared.urlForApplication(withBundleIdentifier: binding.bundleID)
        guard let appURL else {
            NSSound.beep()
            return
        }
        let options = NSWorkspace.OpenConfiguration()
        options.activates = true
        NSWorkspace.shared.openApplication(at: appURL, configuration: options) { _, error in
            if error != nil { NSSound.beep() }
        }
    }
}
