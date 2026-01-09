import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    // Return false to keep app running in tray when window is closed
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  /// Handle Dock icon click when app is running but window is hidden
  ///
  /// This is called when user clicks the Dock icon while the app is running.
  /// Returns true to indicate we handled the reopen, which shows the main window.
  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !flag {
      // No visible windows, show the main window
      if let mainWindow = NSApp.windows.first(where: { $0 is MainFlutterWindow }) {
        mainWindow.makeKeyAndOrderFront(self)
        NSApp.activate(ignoringOtherApps: true)
        print("[AppDelegate] Dock clicked, showing main window")
      }
    }
    return true
  }
}
