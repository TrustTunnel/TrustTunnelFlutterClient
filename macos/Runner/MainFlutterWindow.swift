import Cocoa
import FlutterMacOS
import window_manager

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    registerMacosExitDialogChannel(flutterViewController: flutterViewController)
    registerMacosMainWindowChannel(flutterViewController: flutterViewController)
    registerLaunchAtLoginChannel(flutterViewController: flutterViewController)

    super.awakeFromNib()
    MacOSMainWindowController.shared.attach(self)
  }

  override public func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
    super.order(place, relativeTo: otherWin)
    hiddenWindowAtLaunch()
  }

  private func registerMacosExitDialogChannel(flutterViewController: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "trusttunnel/macos_exit_dialog",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "show" else {
        result(FlutterMethodNotImplemented)

        return
      }

      let arguments = call.arguments as? [String: Any] ?? [:]
      result(MacosExitDialog.show(arguments: arguments, parentWindow: self))
    }
  }

  private func registerMacosMainWindowChannel(flutterViewController: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "trusttunnel/macos_main_window",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] call, result in
      guard self != nil else {
        result(
          FlutterError(
            code: "window_unavailable",
            message: "Main window is unavailable",
            details: nil
          )
        )

        return
      }

      switch call.method {
      case "shouldShowMainWindowOnLaunch":
        result(MacOSMainWindowController.shared.shouldShowMainWindowOnLaunch())
      case "show":
        MacOSMainWindowController.shared.showMainWindow()
        result(nil)
      case "hide":
        MacOSMainWindowController.shared.hideMainWindow()
        result(nil)
      case "getOpenMainWindowOnLogin":
        result(LaunchPresentationDefaults.openMainWindowOnLogin)
      case "setOpenMainWindowOnLogin":
        guard
          let arguments = call.arguments as? [String: Any],
          let enabled = arguments["enabled"] as? Bool
        else {
          result(
            FlutterError(
              code: "invalid_arguments",
              message: "Expected enabled argument",
              details: nil
            )
          )

          return
        }

        LaunchPresentationDefaults.openMainWindowOnLogin = enabled
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func registerLaunchAtLoginChannel(flutterViewController: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "trusttunnel/launch_at_login",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    let manager: LaunchAtLoginManaging = LaunchAtLoginManager()

    channel.setMethodCallHandler { call, result in
      do {
        switch call.method {
        case "isEnabled":
          result(try manager.isEnabled())
        case "setEnabled":
          guard
            let arguments = call.arguments as? [String: Any],
            let enabled = arguments["enabled"] as? Bool
          else {
            throw LaunchAtLoginError.invalidArguments
          }

          try manager.setEnabled(enabled)
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      } catch {
        let nsError = error as NSError
        result(
          FlutterError(
            code: "launch_at_login_error",
            message: nsError.localizedDescription,
            details: [
              "domain": nsError.domain,
              "code": nsError.code,
              "description": nsError.localizedDescription,
            ]
          )
        )
      }
    }
  }
}
