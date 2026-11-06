import AppKit
import CoreGraphics

final class AppSwitcher {
    func toggle(_ binding: Binding) {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: binding.bundleID)
            .first(where: { !$0.isTerminated })

        if let app = running {
            if !AppWindowDetector.hasOpenWindow(processID: app.processIdentifier) {
                reopenWindow(for: binding, running: app)
                return
            }
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier {
                _ = app.hide()
            } else {
                if app.isHidden { _ = app.unhide() }
                _ = app.activate(options: [])
            }
            return
        }

        reopenWindow(for: binding, running: nil)
    }

    private func reopenWindow(for binding: Binding, running: NSRunningApplication?) {
        if binding.bundleID == "com.apple.finder" {
            openFinderWindow()
            return
        }
        let savedURL = URL(fileURLWithPath: binding.appPath)
        let appURL = running?.bundleURL
            ?? (FileManager.default.fileExists(atPath: savedURL.path)
                ? savedURL : NSWorkspace.shared.urlForApplication(withBundleIdentifier: binding.bundleID))
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

    private func openFinderWindow() {
        let finderURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.finder")
            ?? URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")
        let options = NSWorkspace.OpenConfiguration()
        options.activates = true
        NSWorkspace.shared.open([FileManager.default.homeDirectoryForCurrentUser],
                                withApplicationAt: finderURL, configuration: options) { _, error in
            if error != nil { NSSound.beep() }
        }
    }
}

enum AppWindowDetector {
    static func hasOpenWindow(processID: pid_t) -> Bool {
        let windows = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? []
        return hasOpenWindow(in: windows, processID: processID)
    }

    static func hasOpenWindow(in windows: [[String: Any]], processID: pid_t) -> Bool {
        windows.contains { window in
            guard (window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == processID,
                  (window[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                  (window[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue == true,
                  let bounds = window[kCGWindowBounds as String] as? [String: Any],
                  let width = bounds["Width"] as? NSNumber,
                  let height = bounds["Height"] as? NSNumber else { return false }
            // Ignore offscreen helper windows, desktop and menu-bar surfaces.
            return width.doubleValue >= 200 && height.doubleValue >= 100
        }
    }
}
