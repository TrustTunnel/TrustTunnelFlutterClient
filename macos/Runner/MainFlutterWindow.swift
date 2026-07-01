import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    registerMacosExitDialogChannel(flutterViewController: flutterViewController)
    registerMacosMainWindowChannel(flutterViewController: flutterViewController)

    super.awakeFromNib()
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
      guard call.method == "show" else {
        result(FlutterMethodNotImplemented)

        return
      }

      guard let window = self else {
        result(
          FlutterError(
            code: "window_unavailable",
            message: "Main window is unavailable",
            details: nil
          )
        )

        return
      }

      DispatchQueue.main.async {
        if window.isMiniaturized {
          window.deminiaturize(nil)
        }

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        result(nil)
      }
    }
  }
}
