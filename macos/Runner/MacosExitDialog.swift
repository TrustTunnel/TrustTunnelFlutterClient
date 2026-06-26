import Cocoa

final class MacosExitDialog: NSWindowController {
  private enum Metrics {
    static let dialogWidth: CGFloat = 260
    static let dialogHeight: CGFloat = 220
    static let sideInset: CGFloat = 16
    static let shadowInset: CGFloat = 30
    static let windowWidth = dialogWidth + shadowInset * 2
    static let windowHeight = dialogHeight + shadowInset * 2
    static let iconSize: CGFloat = 64
    static let iconTopInset: CGFloat = 20
    static let iconTitleSpacing: CGFloat = 16
    static let titleHeight: CGFloat = 16
    static let titleTextSpacing: CGFloat = 10
    static let messageHeight: CGFloat = 28
    static let messageButtonSpacing: CGFloat = 18
    static let buttonBottomInset: CGFloat = 16
    static let buttonHeight: CGFloat = 32
    static let buttonSpacing: CGFloat = 8
    static let buttonCornerRadius: CGFloat = buttonHeight / 2
    static let cornerRadius: CGFloat = 24
    static let borderWidth: CGFloat = 1
    static let borderColor = NSColor(calibratedWhite: 1, alpha: 0.56)
    static let iconShadowOpacity: Float = 0.25
    static let iconShadowRadius: CGFloat = 2
    static let iconShadowOffset = CGSize(width: 0, height: -1)
  }

  private enum ViewTag {
    static let dontQuitButton = 1
  }

  private struct Configuration {
    let title: String
    let message: String
    let quitButtonText: String
    let dontQuitButtonText: String

    init(arguments: [String: Any]) {
      title = arguments["title"] as? String ?? "Quit TrustTunnel?"
      message = arguments["message"] as? String ?? ""
      quitButtonText = arguments["quitButtonText"] as? String ?? "Quit"
      dontQuitButtonText = arguments["dontQuitButtonText"] as? String ?? "Don't quit"
    }
  }

  private static let lightAppearance = NSAppearance(named: .aqua)

  private var shouldQuit = false
  private weak var parentWindow: NSWindow?

  static func show(arguments: [String: Any], parentWindow: NSWindow?) -> Bool {
    let controller = MacosExitDialog(
      configuration: Configuration(arguments: arguments),
      parentWindow: parentWindow
    )
    controller.centerOverParentWindow()

    let window = controller.window!
    NSApp.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(nil)
    NSApp.runModal(for: window)
    window.close()

    return controller.shouldQuit
  }

  private init(configuration: Configuration, parentWindow: NSWindow?) {
    self.parentWindow = parentWindow

    let panel = MacosExitDialogPanel(
      contentRect: NSRect(x: 0, y: 0, width: Metrics.windowWidth, height: Metrics.windowHeight),
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )
    Self.configure(panel)

    super.init(window: panel)

    let contentView = makeContentView(configuration: configuration)
    panel.contentView = contentView
    panel.initialFirstResponder = contentView.findButton(tag: ViewTag.dontQuitButton)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func cancelOperation(_ sender: Any?) {
    closeDialog(shouldQuit: false)
  }

  private static func configure(_ panel: MacosExitDialogPanel) {
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.isFloatingPanel = true
    panel.isMovable = true
    panel.isMovableByWindowBackground = true
    panel.level = .modalPanel
    panel.animationBehavior = .alertPanel
    panel.collectionBehavior = [.transient]
    panel.appearance = lightAppearance
  }

  private func makeContentView(configuration: Configuration) -> NSView {
    let rootView = MacosExitDialogDraggableView(
      frame: NSRect(x: 0, y: 0, width: Metrics.windowWidth, height: Metrics.windowHeight)
    )
    rootView.wantsLayer = true
    rootView.layer?.backgroundColor = NSColor.clear.cgColor

    let contentView = makeDialogContainer()
    rootView.addSubview(contentView)

    let overlayView = makeMaterialBackground(in: contentView)
    addContent(to: overlayView, configuration: configuration)

    return rootView
  }

  private func makeDialogContainer() -> MacosExitDialogDraggableView {
    let contentView = MacosExitDialogDraggableView(
      frame: NSRect(
        x: Metrics.shadowInset,
        y: Metrics.shadowInset,
        width: Metrics.dialogWidth,
        height: Metrics.dialogHeight
      )
    )
    contentView.wantsLayer = true
    contentView.layer?.cornerRadius = Metrics.cornerRadius
    contentView.layer?.masksToBounds = false
    contentView.layer?.backgroundColor = NSColor.clear.cgColor
    contentView.layer?.shadowColor = NSColor.black.cgColor
    contentView.layer?.shadowOpacity = 0.36
    contentView.layer?.shadowRadius = 24
    contentView.layer?.shadowOffset = CGSize(width: 0, height: -8)
    contentView.layer?.shadowPath = NSBezierPath(
      roundedRect: contentView.bounds,
      xRadius: Metrics.cornerRadius,
      yRadius: Metrics.cornerRadius
    ).cgPath

    return contentView
  }

  private func makeMaterialBackground(in contentView: NSView) -> NSView {
    let materialView = MacosExitDialogVisualEffectView(frame: contentView.bounds)
    materialView.autoresizingMask = [.width, .height]
    materialView.material = .hudWindow
    materialView.blendingMode = .behindWindow
    materialView.state = .active
    materialView.wantsLayer = true
    materialView.layer?.cornerRadius = Metrics.cornerRadius
    materialView.layer?.masksToBounds = true
    contentView.addSubview(materialView)

    let overlayView = MacosExitDialogDraggableView(frame: contentView.bounds)
    overlayView.autoresizingMask = [.width, .height]
    overlayView.wantsLayer = true
    overlayView.layer?.cornerRadius = Metrics.cornerRadius
    overlayView.layer?.masksToBounds = true
    overlayView.layer?.backgroundColor = NSColor(calibratedWhite: 1, alpha: 0.26).cgColor
    overlayView.layer?.borderColor = Metrics.borderColor.cgColor
    overlayView.layer?.borderWidth = Metrics.borderWidth
    contentView.addSubview(overlayView)

    return overlayView
  }

  private func addContent(to contentView: NSView, configuration: Configuration) {
    let buttonY = Metrics.buttonBottomInset
    let messageFrame = NSRect(
      x: Metrics.sideInset,
      y: buttonY + Metrics.buttonHeight + Metrics.messageButtonSpacing,
      width: Metrics.dialogWidth - Metrics.sideInset * 2,
      height: Metrics.messageHeight
    )
    let titleFrame = NSRect(
      x: Metrics.sideInset,
      y: messageFrame.maxY + Metrics.titleTextSpacing,
      width: Metrics.dialogWidth - Metrics.sideInset * 2,
      height: Metrics.titleHeight
    )
    let iconFrame = NSRect(
      x: (Metrics.dialogWidth - Metrics.iconSize) / 2,
      y: titleFrame.maxY + Metrics.iconTitleSpacing,
      width: Metrics.iconSize,
      height: Metrics.iconSize
    )
    assert(abs(Metrics.dialogHeight - iconFrame.maxY - Metrics.iconTopInset) < 0.5)

    contentView.addSubview(makeIconView(frame: iconFrame))
    contentView.addSubview(makeTitleLabel(title: configuration.title, frame: titleFrame))
    contentView.addSubview(makeMessageLabel(message: configuration.message, frame: messageFrame))

    let buttonWidth = (Metrics.dialogWidth - Metrics.sideInset * 2 - Metrics.buttonSpacing) / 2
    let quitButton = makeButton(
      title: configuration.quitButtonText,
      frame: NSRect(
        x: Metrics.sideInset,
        y: buttonY,
        width: buttonWidth,
        height: Metrics.buttonHeight
      ),
      backgroundColor: Self.lightResolvedColor(.controlBackgroundColor),
      textColor: Self.lightResolvedColor(.labelColor),
      action: #selector(quitButtonPressed)
    )
    contentView.addSubview(quitButton)

    let dontQuitButton = makeButton(
      title: configuration.dontQuitButtonText,
      frame: NSRect(
        x: Metrics.sideInset + buttonWidth + Metrics.buttonSpacing,
        y: buttonY,
        width: buttonWidth,
        height: Metrics.buttonHeight
      ),
      backgroundColor: .systemBlue,
      textColor: .white,
      action: #selector(dontQuitButtonPressed)
    )
    dontQuitButton.tag = ViewTag.dontQuitButton
    contentView.addSubview(dontQuitButton)
  }

  private func makeIconView(frame: NSRect) -> NSView {
    let iconShadowView = MacosExitDialogDraggableView(frame: frame)
    iconShadowView.wantsLayer = true
    iconShadowView.layer?.shadowColor = NSColor.black.cgColor
    iconShadowView.layer?.shadowOpacity = Metrics.iconShadowOpacity
    iconShadowView.layer?.shadowRadius = Metrics.iconShadowRadius
    iconShadowView.layer?.shadowOffset = Metrics.iconShadowOffset
    iconShadowView.layer?.shadowPath = NSBezierPath(
      roundedRect: iconShadowView.bounds,
      xRadius: 14,
      yRadius: 14
    ).cgPath

    let iconView = MacosExitDialogDraggableImageView(frame: iconShadowView.bounds)
    iconView.image = NSImage(named: "ExitDialogIcon") ?? Self.makePlaceholderIcon()
    iconView.imageScaling = .scaleProportionallyUpOrDown
    iconShadowView.addSubview(iconView)

    return iconShadowView
  }

  private func makeTitleLabel(title: String, frame: NSRect) -> NSTextField {
    let label = NSTextField(labelWithString: title)
    label.frame = frame
    label.alignment = .center
    label.font = .systemFont(ofSize: 13, weight: .bold)
    label.textColor = .black
    label.lineBreakMode = .byTruncatingTail
    return label
  }

  private func makeMessageLabel(message: String, frame: NSRect) -> NSTextField {
    let label = MacosExitDialogDraggableTextField(wrappingLabelWithString: message)
    label.frame = frame
    label.alignment = .center
    label.font = .systemFont(ofSize: 11, weight: .regular)
    label.textColor = .black
    label.isSelectable = false
    label.maximumNumberOfLines = 2
    return label
  }

  private func makeButton(
    title: String,
    frame: NSRect,
    backgroundColor: NSColor,
    textColor: NSColor,
    action: Selector
  ) -> RoundedDialogButton {
    let button = RoundedDialogButton(
      frame: frame,
      title: title,
      backgroundColor: backgroundColor,
      textColor: textColor,
      cornerRadius: Metrics.buttonCornerRadius
    )
    button.target = self
    button.action = action
    return button
  }

  @objc private func quitButtonPressed() {
    closeDialog(shouldQuit: true)
  }

  @objc private func dontQuitButtonPressed() {
    closeDialog(shouldQuit: false)
  }

  private func closeDialog(shouldQuit: Bool) {
    self.shouldQuit = shouldQuit
    NSApp.stopModal()
  }

  private func centerOverParentWindow() {
    guard let window else {
      return
    }

    if let parentWindow {
      window.center(over: parentWindow)
    } else {
      window.center()
    }
  }

  private static func lightResolvedColor(_ color: NSColor) -> NSColor {
    guard let lightAppearance else {
      return color
    }

    var resolvedColor = color
    lightAppearance.performAsCurrentDrawingAppearance {
      resolvedColor = NSColor(cgColor: color.cgColor) ?? color
    }
    return resolvedColor
  }

  private static func makePlaceholderIcon() -> NSImage {
    let image = NSImage(size: NSSize(width: 64, height: 64))
    image.lockFocus()

    NSColor.white.setFill()
    NSBezierPath(
      roundedRect: NSRect(x: 0, y: 0, width: 64, height: 64),
      xRadius: 14,
      yRadius: 14
    ).fill()

    NSColor(calibratedRed: 0.2, green: 0.48, blue: 0.72, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: 11, y: 11, width: 42, height: 42)).fill()

    NSColor.white.setStroke()
    let checkPath = NSBezierPath()
    checkPath.lineWidth = 4
    checkPath.lineCapStyle = .round
    checkPath.lineJoinStyle = .round
    checkPath.move(to: NSPoint(x: 24, y: 33))
    checkPath.line(to: NSPoint(x: 31, y: 26))
    checkPath.line(to: NSPoint(x: 42, y: 39))
    checkPath.stroke()

    image.unlockFocus()
    image.isTemplate = false

    return image
  }
}

private final class MacosExitDialogPanel: NSPanel {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }
}

private final class MacosExitDialogDraggableView: NSView {
  override var mouseDownCanMoveWindow: Bool { true }
}

private final class MacosExitDialogVisualEffectView: NSVisualEffectView {
  override var mouseDownCanMoveWindow: Bool { true }
}

private final class MacosExitDialogDraggableTextField: NSTextField {
  override var mouseDownCanMoveWindow: Bool { true }
}

private final class MacosExitDialogDraggableImageView: NSImageView {
  override var mouseDownCanMoveWindow: Bool { true }
}

private final class RoundedDialogButton: NSControl {
  private let normalColor: NSColor
  private let pressedColor: NSColor
  private let preferredCornerRadius: CGFloat
  private let title: String
  private let textColor: NSColor

  override var acceptsFirstResponder: Bool { true }

  init(
    frame: NSRect,
    title: String,
    backgroundColor: NSColor,
    textColor: NSColor,
    cornerRadius: CGFloat
  ) {
    normalColor = backgroundColor
    pressedColor = backgroundColor.blended(withFraction: 0.12, of: .black) ?? backgroundColor
    preferredCornerRadius = cornerRadius
    self.title = title
    self.textColor = textColor

    super.init(frame: frame)

    wantsLayer = true
    layer?.backgroundColor = normalColor.cgColor
    layer?.cornerRadius = Self.clampedCornerRadius(preferredCornerRadius, for: bounds.size)
    layer?.masksToBounds = true
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func mouseDown(with event: NSEvent) {
    layer?.backgroundColor = pressedColor.cgColor

    guard let mouseUpEvent = window?.nextEvent(matching: [.leftMouseUp]) else {
      layer?.backgroundColor = normalColor.cgColor
      return
    }

    layer?.backgroundColor = normalColor.cgColor
    let mousePoint = convert(mouseUpEvent.locationInWindow, from: nil)
    if bounds.contains(mousePoint) {
      sendAction(action, to: target)
    }
  }

  override func layout() {
    super.layout()
    layer?.cornerRadius = Self.clampedCornerRadius(preferredCornerRadius, for: bounds.size)
    needsDisplay = true
  }

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)

    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = .center
    paragraphStyle.lineBreakMode = .byTruncatingTail

    let attributedTitle = NSAttributedString(
      string: title,
      attributes: [
        .font: NSFont.systemFont(ofSize: 13, weight: .regular),
        .foregroundColor: textColor,
        .paragraphStyle: paragraphStyle,
      ]
    )
    let insetBounds = bounds.insetBy(dx: 8, dy: 0)
    let titleSize = attributedTitle.boundingRect(
      with: NSSize(width: insetBounds.width, height: .greatestFiniteMagnitude),
      options: [.usesLineFragmentOrigin, .usesFontLeading]
    ).size
    let titleHeight = ceil(titleSize.height)
    let titleRect = NSRect(
      x: insetBounds.minX,
      y: bounds.midY - titleHeight / 2,
      width: insetBounds.width,
      height: titleHeight
    )

    attributedTitle.draw(
      with: titleRect,
      options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine]
    )
  }

  override func keyDown(with event: NSEvent) {
    switch event.keyCode {
    case 36, 49, 76:
      sendAction(action, to: target)
    default:
      super.keyDown(with: event)
    }
  }

  private static func clampedCornerRadius(_ cornerRadius: CGFloat, for size: NSSize) -> CGFloat {
    min(cornerRadius, min(size.width, size.height) / 2)
  }
}

private extension NSView {
  func findButton(tag: Int) -> RoundedDialogButton? {
    if let button = self as? RoundedDialogButton, button.tag == tag {
      return button
    }

    for subview in subviews {
      if let button = subview.findButton(tag: tag) {
        return button
      }
    }

    return nil
  }
}

private extension NSWindow {
  func center(over parentWindow: NSWindow) {
    let parentFrame = parentWindow.frame
    let newOrigin = NSPoint(
      x: parentFrame.midX - frame.width / 2,
      y: parentFrame.midY - frame.height / 2
    )
    setFrameOrigin(newOrigin)
  }
}
