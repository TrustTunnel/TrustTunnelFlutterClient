import Flutter
import UIKit

public final class AdgSharePlugin: NSObject, FlutterPlugin {
    private weak var presentingViewController: UIViewController?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "adg_share", binaryMessenger: registrar.messenger())
        let instance = AdgSharePlugin()
        instance.presentingViewController = registrar.viewController
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "share":
            handleShare(call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func handleShare(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any],
              let rawContent = arguments["content"] as? [[String: Any]],
              !rawContent.isEmpty else {
            result(FlutterError(code: "validation_error", message: "Share request content must not be empty.", details: nil))
            return
        }

        DispatchQueue.main.async {
            guard let presentingController = self.resolvePresentingViewController() else {
                result(["status": "unavailable"])
                return
            }

            do {
                let activityItems = try self.buildActivityItems(from: rawContent)
                let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)

                if let subject = (arguments["subject"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !subject.isEmpty {
                    controller.setValue(subject, forKey: "subject")
                }

                if let excludedTargets = arguments["excludedTargets"] as? [String], !excludedTargets.isEmpty {
                    controller.excludedActivityTypes = excludedTargets.map(UIActivity.ActivityType.init(rawValue:))
                }

                if let popover = controller.popoverPresentationController {
                    popover.sourceView = presentingController.view
                    popover.sourceRect = self.resolveSourceRect(
                        from: arguments["sharePositionOrigin"] as? [String: Any],
                        in: presentingController.view,
                    )
                    popover.permittedArrowDirections = []
                }

                controller.completionWithItemsHandler = { _, completed, _, error in
                    if let error {
                        result(FlutterError(code: "share_failed", message: error.localizedDescription, details: nil))
                        return
                    }

                    result(["status": completed ? "success" : "dismissed"])
                }

                presentingController.present(controller, animated: true)
            } catch let error as SharePluginError {
                result(FlutterError(code: error.code, message: error.message, details: nil))
            } catch {
                result(FlutterError(code: "share_failed", message: error.localizedDescription, details: nil))
            }
        }
    }

    private func buildActivityItems(from rawContent: [[String: Any]]) throws -> [Any] {
        var activityItems = [Any]()

        for item in rawContent {
            guard let type = item["type"] as? String else {
                continue
            }

            switch type {
            case "text":
                guard let text = (item["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !text.isEmpty else {
                    throw SharePluginError(code: "validation_error", message: "Share text must not be empty.")
                }
                activityItems.append(text)
            case "uri":
                guard let rawUri = (item["uri"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                      let url = URL(string: rawUri),
                      url.scheme != nil else {
                    throw SharePluginError(code: "validation_error", message: "Share URI must contain a scheme.")
                }
                activityItems.append(url)
            case "file":
                guard let filePath = (item["path"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !filePath.isEmpty else {
                    throw SharePluginError(code: "validation_error", message: "Share file path must not be empty.")
                }

                guard FileManager.default.fileExists(atPath: filePath) else {
                    throw SharePluginError(code: "file_not_found", message: filePath)
                }

                activityItems.append(URL(fileURLWithPath: filePath))
            default:
                continue
            }
        }

        if activityItems.isEmpty {
            throw SharePluginError(code: "validation_error", message: "Share request content must not be empty.")
        }

        return activityItems
    }

    private func resolvePresentingViewController() -> UIViewController? {
        var controller = presentingViewController

        if controller == nil {
            controller = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first(where: \.isKeyWindow)?.rootViewController
        }

        if controller == nil {
            controller = UIApplication.shared.delegate?.window??.rootViewController
        }

        if let navigationController = controller as? UINavigationController {
            controller = navigationController.visibleViewController ?? navigationController.topViewController ?? navigationController
        } else if let tabBarController = controller as? UITabBarController {
            controller = tabBarController.selectedViewController ?? tabBarController
        }

        while let presentedViewController = controller?.presentedViewController,
              !presentedViewController.isBeingDismissed {
            controller = presentedViewController
        }

        return controller
    }

    private func resolveSourceRect(from rawRect: [String: Any]?, in view: UIView) -> CGRect {
        guard let rawRect,
              let left = rawRect["left"] as? Double,
              let top = rawRect["top"] as? Double,
              let right = rawRect["right"] as? Double,
              let bottom = rawRect["bottom"] as? Double else {
            return CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        }

        let width = max(right - left, 1)
        let height = max(bottom - top, 1)
        return CGRect(x: left, y: top, width: width, height: height)
    }
}

private struct SharePluginError: Error {
    let code: String
    let message: String
}
