// Native implementation of the `tray_manager` Flutter plugin for macOS.
//
// This file implements a macOS status bar tray icon and menu using `NSStatusItem`
// and `NSMenu`. Communication with Dart happens through `FlutterBasicMessageChannel`
// with `FlutterStandardMessageCodec`.
//
// Incoming messages from Dart:
// - tray_manager/trayApi/initTray
// - tray_manager/trayApi/updateMenu
// - tray_manager/trayApi/disposeTray
//
// Outgoing callbacks to Dart:
// - tray_manager/trayCallbackApi/onMenuItemClickedId
import Cocoa
import FlutterMacOS

private enum TrayMenuItemType: String {
  case status
  case button
  case separator
}

private struct TrayManagerError: Error {
  let code: String
  let message: String
  let details: Any?
}

private func swiftTypeName(_ value: Any?) -> String {
  guard let value else { return "nil" }
  return String(describing: type(of: value))
}

private struct TrayMenuItem {
  let id: String?
  let text: String?
  let isEnabled: Bool?
  let isChecked: Bool
  let type: TrayMenuItemType
  let iconPng: Data?
  let children: [TrayMenuItem]?
  let isMonochrome: Bool

  static func fromMap(_ map: [String: Any?], path: String) throws -> TrayMenuItem {
    let id = map["id"] as? String
    let text = map["text"] as? String
    let isEnabled = map["isEnabled"] as? Bool

    let isChecked = (map["isChecked"] as? Bool) ?? false

    guard let typeRaw = map["type"] as? String else {
      throw TrayManagerError(
        code: "argument-error",
        message: "Invalid value for 'type'",
        details: [
          "path": "\(path).type",
          "expected": "String",
          "actual": swiftTypeName(map["type"] ?? nil),
        ]
      )
    }

    guard let type = TrayMenuItemType(rawValue: typeRaw) else {
      throw TrayManagerError(
        code: "argument-error",
        message: "Unknown tray menu item type: \(typeRaw)",
        details: [
          "path": "\(path).type",
          "allowed": [
            TrayMenuItemType.status.rawValue,
            TrayMenuItemType.button.rawValue,
            TrayMenuItemType.separator.rawValue,
          ],
        ]
      )
    }

    let iconAny: Any? = map["iconPng"] ?? nil
    let iconData: Data?
    if iconAny == nil || iconAny is NSNull {
      iconData = nil
    } else if let typedData = iconAny as? FlutterStandardTypedData {
      iconData = typedData.data
    } else {
      throw TrayManagerError(
        code: "argument-error",
        message: "Invalid value for 'iconPng'",
        details: [
          "path": "\(path).iconPng",
          "expected": "Uint8List (FlutterStandardTypedData) or null",
          "actual": swiftTypeName(iconAny),
        ]
      )
    }

    let childrenAny: Any? = map["children"] ?? nil
    let children: [TrayMenuItem]?
    if childrenAny == nil || childrenAny is NSNull {
      children = nil
    } else if let childrenList = childrenAny as? [[String: Any?]] {
      children = try childrenList.enumerated().map { idx, childMap in
        try TrayMenuItem.fromMap(childMap, path: "\(path).children[\(idx)]")
      }
    } else {
      throw TrayManagerError(
        code: "argument-error",
        message: "Invalid value for 'children'",
        details: [
          "path": "\(path).children",
          "expected": "List<Map<String, dynamic>> or null",
          "actual": swiftTypeName(childrenAny),
        ]
      )
    }

    let isMonochrome = map["isMonochrome"] as? Bool ?? false

    return TrayMenuItem(
      id: id,
      text: text,
      isEnabled: isEnabled,
      isChecked: isChecked,
      type: type,
      iconPng: iconData,
      children: children,
      isMonochrome: isMonochrome
    )
  }
}

public class TrayManagerMacosPlugin: NSObject, FlutterPlugin {
  private var statusItem: NSStatusItem?
  private var callbackChannel: FlutterBasicMessageChannel?
  private var menuItems: [TrayMenuItem] = []
  private var menu: NSMenu?
  private var trayIconPng: Data?
  private var isTrayIconMonochrome: Bool = false

  private static let codec = FlutterStandardMessageCodec.sharedInstance()

  private static let trayApiPrefix = "tray_manager/trayApi/"
  private static let initTrayChannelName = trayApiPrefix + "initTray"
  private static let updateMenuChannelName = trayApiPrefix + "updateMenu"
  private static let disposeTrayChannelName = trayApiPrefix + "disposeTray"
  private static let setTrayIconChannelName = trayApiPrefix + "setTrayIconPng"
  private static let onMenuItemClickedChannelName =
    "tray_manager/trayCallbackApi/onMenuItemClickedId"

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = TrayManagerMacosPlugin()

    instance.callbackChannel = FlutterBasicMessageChannel(
      name: onMenuItemClickedChannelName,
      binaryMessenger: registrar.messenger,
      codec: codec
    )

    let initTrayChannel = FlutterBasicMessageChannel(
      name: initTrayChannelName,
      binaryMessenger: registrar.messenger,
      codec: codec
    )
    initTrayChannel.setMessageHandler { message, reply in
      do {
        guard let args = message as? [Any?], let itemsArg = args.first as? [[String: Any?]] else {
          throw TrayManagerError(
            code: "argument-error",
            message: "Invalid arguments for initTray",
            details: [
              "expected": "[List<Map<String, dynamic>>]",
              "actual": swiftTypeName(message),
            ]
          )
        }

        instance.menuItems = try itemsArg.enumerated().map { idx, itemMap in
          try TrayMenuItem.fromMap(itemMap, path: "menuItems[\(idx)]")
        }
        instance.buildTray()
        reply([nil])
      } catch let err as TrayManagerError {
        reply([err.code, err.message, err.details])
      } catch {
        reply(["native-error", "Unexpected error", String(describing: error)])
      }
    }

    let updateMenuChannel = FlutterBasicMessageChannel(
      name: updateMenuChannelName,
      binaryMessenger: registrar.messenger,
      codec: codec
    )
    updateMenuChannel.setMessageHandler { message, reply in
      do {
        guard let args = message as? [Any?], let itemsArg = args.first as? [[String: Any?]] else {
          throw TrayManagerError(
            code: "argument-error",
            message: "Invalid arguments for updateMenu",
            details: [
              "expected": "[List<Map<String, dynamic>>]",
              "actual": swiftTypeName(message),
            ]
          )
        }

        instance.menuItems = try itemsArg.enumerated().map { idx, itemMap in
          try TrayMenuItem.fromMap(itemMap, path: "menuItems[\(idx)]")
        }
        instance.rebuildMenu()
        reply([nil])
      } catch let err as TrayManagerError {
        reply([err.code, err.message, err.details])
      } catch {
        reply(["native-error", "Unexpected error", String(describing: error)])
      }
    }

    let disposeTrayChannel = FlutterBasicMessageChannel(
      name: disposeTrayChannelName,
      binaryMessenger: registrar.messenger,
      codec: codec
    )
    disposeTrayChannel.setMessageHandler { _, reply in
      instance.disposeTray()
      reply([nil])
    }

    let setTrayIconChannel = FlutterBasicMessageChannel(
      name: setTrayIconChannelName,
      binaryMessenger: registrar.messenger,
      codec: codec
    )
    setTrayIconChannel.setMessageHandler { message, reply in
      do {
        guard let args = message as? [Any?] else {
          throw TrayManagerError(
            code: "argument-error",
            message: "Invalid arguments for setTrayIconPng",
            details: [
              "expected": "[Uint8List?]",
              "actual": swiftTypeName(message),
            ]
          )
        }

        let iconAny: Any? = args.first ?? nil
        if iconAny == nil || iconAny is NSNull {
          instance.trayIconPng = nil
        } else if let typedData = iconAny as? FlutterStandardTypedData {
          instance.trayIconPng = typedData.data
        } else {
          throw TrayManagerError(
            code: "argument-error",
            message: "Invalid value for tray icon",
            details: [
              "expected": "Uint8List (FlutterStandardTypedData) or null",
              "actual": swiftTypeName(iconAny),
            ]
          )
        }

        let isMonochrome = args.count > 1 ? (args[1] as? Bool) ?? false : false

        instance.isTrayIconMonochrome = isMonochrome

        instance.applyTrayIcon()
        reply([nil])
      } catch let err as TrayManagerError {
        reply([err.code, err.message, err.details])
      } catch {
        reply(["native-error", "Unexpected error", String(describing: error)])
      }
    }
  }

  private func applyTrayIcon() {
    DispatchQueue.main.async {
      guard let button = self.statusItem?.button else { return }

      if let iconData = self.trayIconPng, let image = NSImage(data: iconData) {
        image.isTemplate = self.isTrayIconMonochrome
        button.image = image
      } else {
        button.image = self.defaultTrayIcon()
      }
      button.imagePosition = .imageOnly
    }
  }

  private func defaultTrayIcon() -> NSImage? {
    if #available(macOS 11.0, *) {
      return NSImage(
        systemSymbolName: "shield.lefthalf.filled",
        accessibilityDescription: "TrustTunnel"
      )
    } else {
      return NSImage(named: NSImage.applicationIconName)
    }
  }

  private func disposeTray() {
    DispatchQueue.main.async {
      if let item = self.statusItem {
        NSStatusBar.system.removeStatusItem(item)
        self.statusItem = nil
      }
      self.menu = nil
      self.menuItems = []
      self.trayIconPng = nil
      self.isTrayIconMonochrome = false
    }
  }

  private func buildTray() {
    DispatchQueue.main.async {
      // If tray already exists, just rebuild the menu (icon is set via setTrayIcon)
      if self.statusItem != nil {
        self.rebuildMenu()
        return
      }

      let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
      self.statusItem = item

      if let button = item.button {
        // Apply icon that was set via setTrayIcon before initTray
        if let iconData = self.trayIconPng, let image = NSImage(data: iconData) {
          image.isTemplate = self.isTrayIconMonochrome
          button.image = image
        } else {
          button.image = self.defaultTrayIcon()
        }
        button.imagePosition = .imageOnly
      }

      self.rebuildMenu()
    }
  }

  private func rebuildMenu() {
    DispatchQueue.main.async {
      guard let statusItem = self.statusItem else { return }

      let menu: NSMenu
      if let existingMenu = self.menu {
        menu = existingMenu
      } else {
        let newMenu = NSMenu()
        newMenu.autoenablesItems = false
        self.menu = newMenu
        menu = newMenu
      }

      self.updateMenu(menu, with: self.menuItems)
      statusItem.menu = menu
      menu.update()
    }
  }

  private func updateMenu(_ menu: NSMenu, with items: [TrayMenuItem]) {
    menu.autoenablesItems = false

    let existingCount = menu.items.count
    let desiredCount = items.count
    let commonCount = min(existingCount, desiredCount)

    for idx in 0..<commonCount {
      let desired = items[idx]
      let existing = menu.items[idx]

      if !self.canReuse(existingMenuItem: existing, for: desired) {
        menu.removeItem(at: idx)
        menu.insertItem(self.createNSMenuItem(from: desired), at: idx)
        continue
      }

      self.apply(desired, to: existing)
    }

    if existingCount > desiredCount {
      for _ in desiredCount..<existingCount {
        menu.removeItem(at: desiredCount)
      }
    }

    if desiredCount > existingCount {
      for idx in existingCount..<desiredCount {
        menu.addItem(self.createNSMenuItem(from: items[idx]))
      }
    }
  }

  private func canReuse(existingMenuItem: NSMenuItem, for desired: TrayMenuItem) -> Bool {
    if desired.type == .separator {
      return existingMenuItem.isSeparatorItem
    }

    if desired.type == .status {
      return existingMenuItem.view != nil
    }

    if existingMenuItem.isSeparatorItem { return false }
    if existingMenuItem.view != nil { return false }

    let desiredHasChildren = (desired.children?.isEmpty == false)
    let existingHasSubmenu = (existingMenuItem.submenu != nil)
    return desiredHasChildren == existingHasSubmenu
  }

  private func apply(_ desired: TrayMenuItem, to existing: NSMenuItem) {
    if desired.type == .separator {
      return
    }

    if desired.type == .status {
      if let stack = existing.view as? NSStackView,
        let label = stack.views.first as? NSTextField
      {
        label.stringValue = desired.text ?? ""
        return
      }

      existing.view = makeStatusMenuItem(value: desired.text ?? "").view
      return
    }

    existing.title = desired.text ?? ""
    existing.isEnabled = desired.isEnabled ?? true
    existing.state = desired.isChecked ? .on : .off

    if let iconData = desired.iconPng, let image = NSImage(data: iconData) {
      image.isTemplate = desired.isMonochrome
      existing.image = image
    } else {
      existing.image = nil
    }

    if let children = desired.children, !children.isEmpty {
      let submenu: NSMenu
      if let existingSubmenu = existing.submenu {
        submenu = existingSubmenu
      } else {
        let newSubmenu = NSMenu()
        newSubmenu.autoenablesItems = false
        existing.submenu = newSubmenu
        submenu = newSubmenu
      }
      self.updateMenu(submenu, with: children)

      existing.target = nil
      existing.action = nil
      existing.representedObject = nil
      return
    }

    let id = (desired.id ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    if id.isEmpty {
      existing.isEnabled = false
      existing.target = nil
      existing.action = nil
      existing.representedObject = nil
      return
    }

    existing.submenu = nil
    existing.target = self
    existing.action = #selector(onMenuItemClick(_:))
    existing.representedObject = id
  }

  private func appendItems(_ items: [TrayMenuItem], to menu: NSMenu) {
    for item in items {
      let nsItem = self.createNSMenuItem(from: item)
      menu.addItem(nsItem)
    }
  }

  private func createNSMenuItem(from item: TrayMenuItem) -> NSMenuItem {
    // Separator
    if item.type == .separator {
      return .separator()
    }

    // Status item (custom view)
    if item.type == .status {
      return makeStatusMenuItem(value: item.text ?? "")
    }

    // Button / Submenu
    let nsItem = NSMenuItem(title: item.text ?? "", action: nil, keyEquivalent: "")
    nsItem.isEnabled = item.isEnabled ?? true
    nsItem.state = item.isChecked ? .on : .off

    if let iconData = item.iconPng, let image = NSImage(data: iconData) {
      image.isTemplate = item.isMonochrome
      nsItem.image = image
    }

    // Submenu
    if let children = item.children, !children.isEmpty {
      let submenu = NSMenu()
      submenu.autoenablesItems = false
      self.appendItems(children, to: submenu)
      nsItem.submenu = submenu
      return nsItem
    }

    // Leaf button: require a valid id
    let id = (item.id ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    if id.isEmpty {
      nsItem.isEnabled = false
      nsItem.target = nil
      nsItem.action = nil
      nsItem.representedObject = nil
      NSLog(
        "[native] WARNING: Missing id for button item '%@'. Disabled.",
        nsItem.title)
      return nsItem
    }

    nsItem.target = self
    nsItem.action = #selector(onMenuItemClick(_:))
    nsItem.representedObject = id
    return nsItem
  }

  @objc private func onMenuItemClick(_ sender: NSMenuItem) {
    let id = sender.representedObject as? String ?? ""
    let payload: [Any?] = [
      id
    ]

    callbackChannel?.sendMessage(payload) { _ in }
  }

  @objc private func onQuit() {
    NSApp.terminate(nil)
  }
}

private func makeStatusMenuItem(value: String) -> NSMenuItem {
  let item = NSMenuItem()

  let label = NSTextField(labelWithString: value)
  label.font = NSFont.menuFont(ofSize: 0)
  label.textColor = .labelColor
  label.alignment = .left

  let container = NSStackView(views: [label])
  container.orientation = .horizontal
  container.edgeInsets = NSEdgeInsets(top: 2, left: 14, bottom: 2, right: 14)

  item.view = container
  return item
}
