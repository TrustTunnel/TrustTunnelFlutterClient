import Cocoa
import FlutterMacOS
import app_links

private enum LoginItemLaunchEvent {
  static let scheme = "tt"

  private static let host = "internal-launch"
  private static let path = "/login-item"

  static var url: URL {
    URL(string: "\(scheme)://\(host)\(path)")!
  }

  static func matches(_ url: URL) -> Bool {
    url.scheme?.caseInsensitiveCompare(scheme) == .orderedSame
      && url.host?.caseInsensitiveCompare(host) == .orderedSame
      && url.path == path
  }
}

private final class AppLaunchState {
  static let shared = AppLaunchState()

  private var isLoginItemLaunch = false

  private init() {}

  var shouldShowMainWindowOnLaunch: Bool {
    !isLoginItemLaunch || LaunchPresentationDefaults.openMainWindowOnLogin
  }

  func markLoginItemLaunch() {
    isLoginItemLaunch = true
  }
}

@main
class AppDelegate: FlutterAppDelegate {
  override init() {
    super.init()
    registerGetURLHandler()
  }

  override func applicationWillFinishLaunching(_ notification: Notification) {
    super.applicationWillFinishLaunching(notification)
    registerGetURLHandler()
    updateLaunchPresentation()
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    updateLaunchPresentation()
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

  @objc
  private func handleGetURLEvent(
    _ event: NSAppleEventDescriptor,
    with replyEvent: NSAppleEventDescriptor
  ) {
    guard
      let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
      let url = URL(string: urlString)
    else {
      return
    }

    if LoginItemLaunchEvent.matches(url) {
      AppLaunchState.shared.markLoginItemLaunch()
      updateLaunchPresentation()

      return
    }

    AppLinks.shared.handleLink(link: url.absoluteString)
  }

  private func registerGetURLHandler() {
    NSAppleEventManager.shared().setEventHandler(
      self,
      andSelector: #selector(handleGetURLEvent(_:with:)),
      forEventClass: AEEventClass(kInternetEventClass),
      andEventID: AEEventID(kAEGetURL)
    )
  }

  private func updateLaunchPresentation() {
    guard !AppLaunchState.shared.shouldShowMainWindowOnLaunch else {
      return
    }

    NSApp.setActivationPolicy(.accessory)
    NSApp.hide(nil)
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

      (window as? MainFlutterWindow)?.allowPresentation()

      if window.isMiniaturized {
        window.deminiaturize(nil)
      }

      window.orderFrontRegardless()
      window.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
    }
  }

  func completeLaunch() {
    DispatchQueue.main.async {
      (self.mainWindow as? MainFlutterWindow)?.completeLaunch()
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
