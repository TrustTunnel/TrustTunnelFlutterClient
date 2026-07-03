import Cocoa

protocol LaunchAtLoginManaging {
  func isEnabled() throws -> Bool

  func setEnabled(_ enabled: Bool) throws
}

final class LaunchAtLoginManager: LaunchAtLoginManaging {
  private static let helperBundleIdentifierFallback = "com.adguard.TrustTunnel.LoginHelper"

  private var helperBundleIdentifier: String {
    guard let mainBundleIdentifier = Bundle.main.bundleIdentifier, !mainBundleIdentifier.isEmpty else {
      return Self.helperBundleIdentifierFallback
    }

    return "\(mainBundleIdentifier).LoginHelper"
  }

  func isEnabled() throws -> Bool {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
    process.arguments = [
      "print",
      "gui/\(getuid())/\(helperBundleIdentifier)",
    ]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice

    try process.run()
    process.waitUntilExit()

    return process.terminationStatus == 0
  }

  func setEnabled(_ enabled: Bool) throws {
    guard let setEnabled = LoginItemServiceManagement.loginItemSetEnabled else {
      throw LaunchAtLoginError.registrationApiUnavailable
    }

    guard setEnabled(helperBundleIdentifier as CFString, enabled) else {
      throw LaunchAtLoginError.registrationFailed
    }
  }
}

private enum LoginItemServiceManagement {
  typealias SMLoginItemSetEnabledFunction = @convention(c) (CFString, Bool) -> Bool

  static let loginItemSetEnabled: SMLoginItemSetEnabledFunction? = {
    _ = dlopen(
      "/System/Library/Frameworks/ServiceManagement.framework/ServiceManagement",
      RTLD_LAZY
    )

    guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "SMLoginItemSetEnabled") else {
      return nil
    }

    return unsafeBitCast(symbol, to: SMLoginItemSetEnabledFunction.self)
  }()
}

enum LaunchAtLoginError: Error {
  case invalidArguments
  case registrationApiUnavailable
  case registrationFailed
}

extension LaunchAtLoginError: LocalizedError {
  var errorDescription: String? {
    switch self {
    case .invalidArguments:
      return "Expected enabled argument"
    case .registrationApiUnavailable:
      return "Login item registration API is unavailable"
    case .registrationFailed:
      return "Login item registration failed"
    }
  }
}
