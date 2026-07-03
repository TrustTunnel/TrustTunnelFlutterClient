import Cocoa

private enum LoginItemLaunchEvent {
  static let scheme = "tt"

  private static let host = "internal-launch"
  private static let path = "/login-item"

  static var url: URL {
    URL(string: "\(scheme)://\(host)\(path)")!
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

    do {
      _ = try NSWorkspace.shared.open(
        [LoginItemLaunchEvent.url],
        withApplicationAt: mainAppUrl,
        options: [.withoutActivation],
        configuration: [:]
      )
    } catch {
      _ = NSWorkspace.shared.open(LoginItemLaunchEvent.url)
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
