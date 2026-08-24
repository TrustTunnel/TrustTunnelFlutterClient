import Cocoa
import FlutterMacOS

private enum LaunchSplashStyle {
  static let backgroundColor = NSColor(
    srgbRed: 230.0 / 255.0,
    green: 234.0 / 255.0,
    blue: 239.0 / 255.0,
    alpha: 1
  )
  static let logoSize = NSSize(width: 147, height: 24)
}

class MainFlutterWindow: NSWindow {
  private var isPresentationAllowed = false
  private weak var launchSplashView: NSView?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    alphaValue = 0
    backgroundColor = LaunchSplashStyle.backgroundColor
    flutterViewController.backgroundColor = LaunchSplashStyle.backgroundColor

    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    installLaunchSplash(in: flutterViewController.view)

    RegisterGeneratedPlugins(registry: flutterViewController)
    registerMacosExitDialogChannel(flutterViewController: flutterViewController)
    registerMacosMainWindowChannel(flutterViewController: flutterViewController)
    registerLaunchAtLoginChannel(flutterViewController: flutterViewController)

    super.awakeFromNib()
    MacOSMainWindowController.shared.attach(self)
  }

  override public func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
    guard place != .out, !isPresentationAllowed else {
      super.order(place, relativeTo: otherWin)

      return
    }

    super.order(place, relativeTo: otherWin)
    setIsVisible(false)
  }

  func allowPresentation() {
    isPresentationAllowed = true
    alphaValue = 1

    if launchSplashView != nil {
      setWindowButtonsHidden(true)
    }
  }

  func completeLaunch() {
    guard let launchSplashView else {
      return
    }

    self.launchSplashView = nil
    launchSplashView.removeFromSuperview()
    setWindowButtonsHidden(false)
  }

  private func installLaunchSplash(in flutterView: NSView) {
    let splashView = NSView()
    splashView.translatesAutoresizingMaskIntoConstraints = false
    splashView.wantsLayer = true
    splashView.layer?.backgroundColor = LaunchSplashStyle.backgroundColor.cgColor

    flutterView.addSubview(splashView)
    NSLayoutConstraint.activate([
      splashView.leadingAnchor.constraint(equalTo: flutterView.leadingAnchor),
      splashView.trailingAnchor.constraint(equalTo: flutterView.trailingAnchor),
      splashView.topAnchor.constraint(equalTo: flutterView.topAnchor),
      splashView.bottomAnchor.constraint(equalTo: flutterView.bottomAnchor),
    ])

    if let logo = NSImage(named: "SplashLogo") {
      logo.isTemplate = false
      let logoView = NSImageView(image: logo)
      logoView.translatesAutoresizingMaskIntoConstraints = false
      logoView.imageAlignment = .alignCenter
      logoView.imageScaling = .scaleProportionallyDown
      splashView.addSubview(logoView)

      NSLayoutConstraint.activate([
        logoView.centerXAnchor.constraint(equalTo: splashView.centerXAnchor),
        logoView.centerYAnchor.constraint(equalTo: splashView.centerYAnchor),
        logoView.widthAnchor.constraint(equalToConstant: LaunchSplashStyle.logoSize.width),
        logoView.heightAnchor.constraint(equalToConstant: LaunchSplashStyle.logoSize.height),
      ])
    }

    launchSplashView = splashView
  }

  private func setWindowButtonsHidden(_ hidden: Bool) {
    standardWindowButton(.closeButton)?.isHidden = hidden
    standardWindowButton(.miniaturizeButton)?.isHidden = hidden
    standardWindowButton(.zoomButton)?.isHidden = hidden
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
      case "completeLaunch":
        MacOSMainWindowController.shared.completeLaunch()
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
