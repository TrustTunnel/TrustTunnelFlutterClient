import Cocoa
import FlutterMacOS
import app_links

private enum LoginItemLaunchEvent {
  // LaunchServices sets this parameter when it starts the app as a login item.
  static func isLaunchedAsLogInItem(_ event: NSAppleEventDescriptor) -> Bool {
    event.paramDescriptor(forKeyword: keyAELaunchedAsLogInItem)?.booleanValue ?? false
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
    registerAppleEventHandlers()
  }

  override func applicationWillFinishLaunching(_ notification: Notification) {
    super.applicationWillFinishLaunching(notification)
    registerAppleEventHandlers()

    // The app lives in the menu bar until the main window is presented. Starting as an
    // accessory app keeps the Dock icon from appearing before it is known whether the
    // window will be shown at all.
    NSApp.setActivationPolicy(.accessory)
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    // `keyAELaunchedAsLogInItem` is not reliably delivered for `SMAppService` login items,
    // so AppKit's own launch reason is used as an additional signal: a launch that is not
    // user-initiated means macOS started the app as a login item.
    if let isDefaultLaunch = notification.userInfo?[NSApplication.launchIsDefaultUserInfoKey] as? Bool,
       !isDefaultLaunch {
      AppLaunchState.shared.markLoginItemLaunch()
    }

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
  private func handleOpenApplicationEvent(
    _ event: NSAppleEventDescriptor,
    with replyEvent: NSAppleEventDescriptor
  ) {
    guard LoginItemLaunchEvent.isLaunchedAsLogInItem(event) else {
      return
    }

    AppLaunchState.shared.markLoginItemLaunch()
    updateLaunchPresentation()
  }

  @objc
  private func handleGetURLEvent(
    _ event: NSAppleEventDescriptor,
    with replyEvent: NSAppleEventDescriptor
  ) {
    guard
      let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue
    else {
      return
    }

    AppLinks.shared.handleLink(link: urlString)
  }

  private func registerAppleEventHandlers() {
    let manager = NSAppleEventManager.shared()

    manager.setEventHandler(
      self,
      andSelector: #selector(handleOpenApplicationEvent(_:with:)),
      forEventClass: AEEventClass(kCoreEventClass),
      andEventID: AEEventID(kAEOpenApplication)
    )
    manager.setEventHandler(
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
