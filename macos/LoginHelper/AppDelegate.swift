import Cocoa

private enum LoginItemLaunchMarkerStorage {
  static let applicationGroupIdentifier = "group.com.adguard.TrustTunnel"

  private static let markerFileName = "login_item_launch_marker.plist"
  private static let sourceKey = "source"
  private static let timestampKey = "timestamp"
  private static let loginItemSourceValue = "login_item"

  static func markLoginItemLaunch() {
    guard let markerFileUrl else {
      return
    }

    let payload: [String: Any] = [
      sourceKey: loginItemSourceValue,
      timestampKey: Date().timeIntervalSince1970,
    ]

    do {
      let data = try PropertyListSerialization.data(
        fromPropertyList: payload,
        format: .binary,
        options: 0
      )
      try data.write(to: markerFileUrl, options: .atomic)
    } catch {
      return
    }
  }

  static func clearLoginItemLaunchMarker() {
    guard let markerFileUrl else {
      return
    }

    try? FileManager.default.removeItem(at: markerFileUrl)
  }

  private static var markerFileUrl: URL? {
    FileManager.default
      .containerURL(forSecurityApplicationGroupIdentifier: applicationGroupIdentifier)?
      .appendingPathComponent(markerFileName, isDirectory: false)
  }
}

@main
enum LoginHelperLauncher {
  static func main() {
    launchMainApplicationIfNeeded()
  }

  private static var mainApplicationUrl: URL? {
    var url = Bundle.main.bundleURL

    for _ in 0..<4 {
      url.deleteLastPathComponent()
    }

    return url.pathExtension == "app" ? url : nil
  }

  private static func launchMainApplicationIfNeeded() {
    guard let mainAppUrl = mainApplicationUrl else {
      return
    }

    guard !isMainApplicationRunning(mainAppUrl) else {
      return
    }

    // NSWorkspace.openApplication() behaves unreliably from a login helper process.
    // The synchronous legacy launch API works consistently for this launcher binary.
    LoginItemLaunchMarkerStorage.markLoginItemLaunch()

    do {
      _ = try NSWorkspace.shared.launchApplication(
        at: mainAppUrl,
        options: [.withoutActivation],
        configuration: [:]
      )
    } catch {
      let openConfiguration = NSWorkspace.OpenConfiguration()
      openConfiguration.activates = false

      let semaphore = DispatchSemaphore(value: 0)
      var didLaunchMainApplication = false

      NSWorkspace.shared.openApplication(at: mainAppUrl, configuration: openConfiguration) { application, error in
        didLaunchMainApplication = application != nil && error == nil
        semaphore.signal()
      }

      _ = semaphore.wait(timeout: .now() + 10)

      if !didLaunchMainApplication {
        LoginItemLaunchMarkerStorage.clearLoginItemLaunchMarker()
      }
    }
  }

  private static func isMainApplicationRunning(_ mainAppUrl: URL) -> Bool {
    let resolvedMainAppUrl = mainAppUrl.resolvingSymlinksInPath().standardizedFileURL
    let mainBundleIdentifier = Bundle(url: mainAppUrl)?.bundleIdentifier

    return NSWorkspace.shared.runningApplications.contains { application in
      let resolvedBundleUrl = application.bundleURL?.resolvingSymlinksInPath().standardizedFileURL

      if resolvedBundleUrl == resolvedMainAppUrl {
        return true
      }

      guard let mainBundleIdentifier else {
        return false
      }

      return application.bundleIdentifier == mainBundleIdentifier
    }
  }
}
