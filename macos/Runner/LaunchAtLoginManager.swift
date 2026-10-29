import Foundation
import ServiceManagement

protocol LaunchAtLoginManaging {
  var isEnabled: Bool { get }

  func setEnabled(_ enabled: Bool) throws

  func migrateLegacyLoginItemIfNeeded()
}

final class LaunchAtLoginManager: LaunchAtLoginManaging {
  private static let legacyHelperBundleIdentifier = "com.adguard.TrustTunnel.LoginHelper"
  private static let legacyMigrationKey = "launch_at_login_migrated_to_app_service"

  var isEnabled: Bool {
    SMAppService.mainApp.status == .enabled
  }

  func setEnabled(_ enabled: Bool) throws {
    let service = SMAppService.mainApp

    guard enabled else {
      guard service.status != .notRegistered else {
        return
      }

      try service.unregister()

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
  func migrateLegacyLoginItemIfNeeded() {
    let defaults = UserDefaults.standard

    guard !defaults.bool(forKey: Self.legacyMigrationKey) else {
      return
    }

    defaults.set(true, forKey: Self.legacyMigrationKey)

    guard
      LegacyLoginItem.isEnabled(identifier: Self.legacyHelperBundleIdentifier),
      SMAppService.mainApp.status == .notRegistered
    else {
      return
    }

    try? SMAppService.mainApp.register()
  }
}

/// Read-only view of the pre-macOS 13 login item state.
///
/// `SMCopyAllJobDictionaries` is the only way to see a legacy login item that `SMAppService`
/// does not track, and it has no modern replacement. It is deprecated since 10.10, so the
/// symbol is resolved at runtime to keep the build warning-free.
private enum LegacyLoginItem {
  typealias CopyAllJobDictionariesFunction = @convention(c) (CFString?) -> CFArray?

  private static let userLaunchdDomain = "kSMDomainUserLaunchd" as CFString

  static func isEnabled(identifier: String) -> Bool {
    guard let copyAllJobDictionaries else {
      return false
    }

    let jobs = copyAllJobDictionaries(userLaunchdDomain) as? [[String: Any]]
    let job = jobs?.first { $0["Label"] as? String == identifier }

    return job?["OnDemand"] as? Bool ?? false
  }

  private static let copyAllJobDictionaries: CopyAllJobDictionariesFunction? = {
    guard
      let handle = dlopen(
        "/System/Library/Frameworks/ServiceManagement.framework/ServiceManagement",
        RTLD_LAZY
      ),
      let symbol = dlsym(handle, "SMCopyAllJobDictionaries")
    else {
      return nil
    }

    return unsafeBitCast(symbol, to: CopyAllJobDictionariesFunction.self)
  }()
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
