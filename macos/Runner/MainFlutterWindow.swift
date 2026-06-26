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
}
