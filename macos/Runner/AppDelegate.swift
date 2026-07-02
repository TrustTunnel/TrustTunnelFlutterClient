import Cocoa
import FlutterMacOS

private enum LoginItemLaunchMarkerStorage {
  static let applicationGroupIdentifier = "group.com.adguard.TrustTunnel"
  static let markerMaxAge: TimeInterval = 30

  private static let markerFileName = "login_item_launch_marker.plist"
  private static let sourceKey = "source"
  private static let timestampKey = "timestamp"
  private static let loginItemSourceValue = "login_item"

  static func consumeLoginItemLaunchMarker() -> Bool {
    guard let markerFileUrl else {
      return false
    }

    defer {
      try? FileManager.default.removeItem(at: markerFileUrl)
    }

    guard
      let data = try? Data(contentsOf: markerFileUrl),
      let propertyList = try? PropertyListSerialization.propertyList(
        from: data,
        options: [],
        format: nil
      ),
      let payload = propertyList as? [String: Any],
      let source = payload[sourceKey] as? String,
      source == loginItemSourceValue,
      let timestamp = payload[timestampKey] as? TimeInterval
    else {
      return false
    }

    return (Date().timeIntervalSince1970 - timestamp) <= markerMaxAge
  }

  private static var markerFileUrl: URL? {
    FileManager.default
      .containerURL(forSecurityApplicationGroupIdentifier: applicationGroupIdentifier)?
      .appendingPathComponent(markerFileName, isDirectory: false)
  }
}

private final class AppLaunchState {
  static let shared = AppLaunchState()

  let shouldShowMainWindowOnLaunch: Bool

  private init() {
    let isLoginItemLaunch = LoginItemLaunchMarkerStorage.consumeLoginItemLaunchMarker()
    shouldShowMainWindowOnLaunch = !isLoginItemLaunch || LaunchPresentationDefaults.openMainWindowOnLogin
  }
}

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationWillFinishLaunching(_ notification: Notification) {
    super.applicationWillFinishLaunching(notification)

    guard !AppLaunchState.shared.shouldShowMainWindowOnLaunch else {
      return
    }

    NSApp.setActivationPolicy(.accessory)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    MacOSMainWindowController.shared.showMainWindow()

    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}

enum LaunchPresentationDefaults {
  static let openMainWindowOnLoginKey = "open_main_window_on_login"

  static var openMainWindowOnLogin: Bool {
    get {
      guard UserDefaults.standard.object(forKey: openMainWindowOnLoginKey) != nil else {
        return false
      }

      return UserDefaults.standard.bool(forKey: openMainWindowOnLoginKey)
    }
    set {
      UserDefaults.standard.set(newValue, forKey: openMainWindowOnLoginKey)
    }
  }
}

final class MacOSMainWindowController {
  static let shared = MacOSMainWindowController()

  private weak var mainWindow: NSWindow?

  private init() {}

  func attach(_ window: NSWindow) {
    mainWindow = window
  }

  func shouldShowMainWindowOnLaunch() -> Bool {
    AppLaunchState.shared.shouldShowMainWindowOnLaunch
  }

  func showMainWindow() {
    DispatchQueue.main.async {
      NSApp.setActivationPolicy(.regular)
      NSApp.unhide(nil)

      guard let window = self.mainWindow else {
        NSApp.activate(ignoringOtherApps: true)

        return
      }

      if window.isMiniaturized {
        window.deminiaturize(nil)
      }

      window.orderFrontRegardless()
      window.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
    }
  }

  func hideMainWindow() {
    DispatchQueue.main.async {
      self.mainWindow?.orderOut(nil)
      NSApp.setActivationPolicy(.accessory)
      NSApp.hide(nil)
    }
  }
}
