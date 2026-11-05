import CoreGraphics
import XCTest
@testable import ShortcutKey

final class AppWindowDetectorTests: XCTestCase {
    func testIgnoresDesktopMenuBarAndOtherAppSurfaces() {
        let pid: pid_t = 42
        let windows: [[String: Any]] = [
            window(pid: pid, layer: -2_147_483_603, width: 1920, height: 1080),
            window(pid: pid, layer: 0, width: 1920, height: 30),
            window(pid: 99, layer: 0, width: 800, height: 600)
        ]
        XCTAssertFalse(AppWindowDetector.hasOpenWindow(in: windows, processID: pid))
        XCTAssertTrue(AppWindowDetector.hasOpenWindow(
            in: windows + [window(pid: pid, layer: 0, width: 800, height: 600)], processID: pid))
    }

    private func window(pid: pid_t, layer: Int, width: Int, height: Int) -> [String: Any] {
        [kCGWindowOwnerPID as String: NSNumber(value: pid),
         kCGWindowLayer as String: NSNumber(value: layer),
         kCGWindowBounds as String: ["Width": NSNumber(value: width), "Height": NSNumber(value: height)]]
    }
}
