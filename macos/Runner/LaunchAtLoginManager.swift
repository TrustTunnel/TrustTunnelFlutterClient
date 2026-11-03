import Foundation
import ServiceManagement

protocol LaunchAtLoginManaging {
  var isEnabled: Bool { get }

  func setEnabled(_ enabled: Bool) throws

  func migrateLegacyLoginItemIfNeeded()
}

final class LaunchAtLoginManager: LaunchAtLoginManaging {
  static let shared = LaunchAtLoginManager()

  private static let legacyHelperBundleIdentifier = "com.adguard.TrustTunnel.LoginHelper"
  private static let legacyMigrationKey = "launch_at_login_migrated_to_app_service"

  var isEnabled: Bool {
    SMAppService.mainApp.status == .enabled
  }

  func setEnabled(_ enabled: Bool) throws {
    let service = SMAppService.mainApp

    guard enabled else {
      // `.notFound` and `.notRegistered` have nothing to unregister, and calling the API
      // for them throws `kSMErrorJobNotFound`.
      switch service.status {
      case .enabled, .requiresApproval:
        try service.unregister()
      default:
        break
      }

      return
    }

    switch service.status {
    case .enabled:
      return
    case .requiresApproval:
      // The item is registered, but the user has to allow it in System Settings.
      SMAppService.openSystemSettingsLoginItems()
    default:
      try service.register()
    }
  }

  /// Before macOS 13 the app was started by a separate helper bundle registered with
  /// `SMLoginItemSetEnabled`. `SMAppService.mainApp` does not see that registration, so the
  /// user's choice has to be carried over once — otherwise autostart silently stops working
  /// after the update.
  ///
  /// The migration is retried on the next launch unless it has definitively completed, so a
  /// failed registration is never recorded as a successful migration.
  func migrateLegacyLoginItemIfNeeded() {
    let defaults = UserDefaults.standard

    guard !defaults.bool(forKey: Self.legacyMigrationKey) else {
      return
    }

    guard let legacyWasEnabled = LegacyLoginItem.isEnabled(identifier: Self.legacyHelperBundleIdentifier) else {
      NSLog("Launch-at-login migration postponed: the legacy login item state is unavailable")

      return
    }

    LegacyLoginItem.disable(identifier: Self.legacyHelperBundleIdentifier)

    guard legacyWasEnabled else {
      defaults.set(true, forKey: Self.legacyMigrationKey)

      return
    }

    guard SMAppService.mainApp.status == .notRegistered else {
      defaults.set(true, forKey: Self.legacyMigrationKey)

      return
    }

    do {
      try SMAppService.mainApp.register()
      defaults.set(true, forKey: Self.legacyMigrationKey)
    } catch {
      NSLog("Launch-at-login migration failed: \(error)")
    }
  }
}

/// Access to the pre-macOS 13 login item, which `SMAppService` does not track.
///
/// `SMCopyAllJobDictionaries` has no modern replacement, and both it and `SMLoginItemSetEnabled`
/// are deprecated, so the symbols are resolved at runtime to keep the build warning-free.
private enum LegacyLoginItem {
  typealias CopyAllJobDictionariesFunction = @convention(c) (CFString?) -> CFArray?
  typealias SetEnabledFunction = @convention(c) (CFString, Bool) -> Bool

  private static let userLaunchdDomain = "kSMDomainUserLaunchd" as CFString

  /// `nil` when the legacy state cannot be read, as opposed to a known disabled item.
  static func isEnabled(identifier: String) -> Bool? {
    guard
      let copyAllJobDictionaries,
      let rawJobs = copyAllJobDictionaries(userLaunchdDomain),
      let jobs = rawJobs as? [[String: Any]]
    else {
      return nil
    }

    let job = jobs.first { $0["Label"] as? String == identifier }

    return job?["OnDemand"] as? Bool ?? false
  }

  /// Best effort: the helper bundle is no longer part of the app, so the system may refuse to
  /// change the registration. A leftover record then has to be removed in System Settings.
  static func disable(identifier: String) {
    _ = loginItemSetEnabled?(identifier as CFString, false)
    try? SMAppService.loginItem(identifier: identifier).unregister()
  }

  private static let copyAllJobDictionaries: CopyAllJobDictionariesFunction? = resolve("SMCopyAllJobDictionaries")

  private static let loginItemSetEnabled: SetEnabledFunction? = resolve("SMLoginItemSetEnabled")

  private static func resolve<T>(_ symbol: String) -> T? {
    guard
      let handle = dlopen(
        "/System/Library/Frameworks/ServiceManagement.framework/ServiceManagement",
        RTLD_LAZY
      ),
      let pointer = dlsym(handle, symbol)
    else {
      return nil
    }

    return unsafeBitCast(pointer, to: T.self)
  }
}

enum LaunchAtLoginError: Error {
  case invalidArguments
}

extension LaunchAtLoginError: LocalizedError {
  var errorDescription: String? {
    switch self {
    case .invalidArguments:
      return "Expected enabled argument"
    }
  }
}
