import Cocoa

fileprivate enum DialogStyleProperties {
    static let dialogWidth: CGFloat = 260
    static let dialogHeight: CGFloat = 220
    static let sideInset: CGFloat = 16
    static let shadowInset: CGFloat = 30
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
    static let iconCornerRadius: CGFloat = 14
    static let placeholderCircleInset: CGFloat = 11
    static let placeholderCheckLineWidth: CGFloat = 4
    static let buttonTitleInset: CGFloat = 8
    static let windowWidth = dialogWidth + shadowInset * 2
    static let windowHeight = dialogHeight + shadowInset * 2
}

fileprivate enum DialogStyleConstants {
    static let lightAppearance = NSAppearance(named: .aqua)
    static let dialogBorderColor = NSColor(calibratedWhite: 1, alpha: 0.56)
    static let overlayBackgroundColor = NSColor(calibratedWhite: 1, alpha: 0.26)
    static let titleTextColor = NSColor.black
    static let messageTextColor = NSColor.black
    static let primaryButtonTextColor = NSColor.white
    static let placeholderBackgroundColor = NSColor.white
    static let placeholderAccentColor = NSColor(
      calibratedRed: 0.2,
      green: 0.48,
      blue: 0.72,
      alpha: 1
    )
    static let dialogShadowColor = NSColor.black
    static let dialogShadowOpacity: Float = 0.36
    static let dialogShadowRadius: CGFloat = 24
    static let dialogShadowOffset = CGSize(width: 0, height: -8)
    static let iconShadowColor = NSColor.black
    static let iconShadowOpacity: Float = 0.25
    static let iconShadowRadius: CGFloat = 2
    static let iconShadowOffset = CGSize(width: 0, height: -1)
    static let titleFont = NSFont.systemFont(ofSize: 13, weight: .bold)
    static let messageFont = NSFont.systemFont(ofSize: 11, weight: .regular)
    static let buttonFont = NSFont.systemFont(ofSize: 13, weight: .regular)
    static let buttonPressedOverlayFraction: CGFloat = 0.12
}

final class MacosExitDialog: NSWindowController {
  private typealias Properties = DialogStyleProperties
  private typealias Constants = DialogStyleConstants

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

  private struct Layout {
    let iconFrame: NSRect
    let titleFrame: NSRect
    let messageFrame: NSRect
    let quitButtonFrame: NSRect
    let dontQuitButtonFrame: NSRect

    init() {
      let buttonWidth = (Properties.dialogWidth - Properties.sideInset * 2 - Properties.buttonSpacing) / 2
      let buttonY = Properties.buttonBottomInset
      let messageFrame = NSRect(
        x: Properties.sideInset,
        y: buttonY + Properties.buttonHeight + Properties.messageButtonSpacing,
        width: Properties.dialogWidth - Properties.sideInset * 2,
        height: Properties.messageHeight
      )
      let titleFrame = NSRect(
        x: Properties.sideInset,
        y: messageFrame.maxY + Properties.titleTextSpacing,
        width: Properties.dialogWidth - Properties.sideInset * 2,
        height: Properties.titleHeight
      )
      let iconFrame = NSRect(
        x: (Properties.dialogWidth - Properties.iconSize) / 2,
        y: titleFrame.maxY + Properties.iconTitleSpacing,
        width: Properties.iconSize,
        height: Properties.iconSize
      )

      assert(abs(Properties.dialogHeight - iconFrame.maxY - Properties.iconTopInset) < 0.5)

      self.iconFrame = iconFrame
      self.titleFrame = titleFrame
      self.messageFrame = messageFrame
      quitButtonFrame = NSRect(
        x: Properties.sideInset,
        y: buttonY,
        width: buttonWidth,
        height: Properties.buttonHeight
      )
      dontQuitButtonFrame = NSRect(
        x: Properties.sideInset + buttonWidth + Properties.buttonSpacing,
        y: buttonY,
        width: buttonWidth,
        height: Properties.buttonHeight
      )
    }
  }

  private struct ContentHierarchy {
    let rootView: NSView
    let initialFirstResponder: NSView?
  }

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

    let panel = DialogPanel(
      contentRect: NSRect(x: 0, y: 0, width: Properties.windowWidth, height: Properties.windowHeight),
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )
    Self.configure(panel)

    super.init(window: panel)

    let hierarchy = makeContentHierarchy(configuration: configuration)
    panel.contentView = hierarchy.rootView
    panel.initialFirstResponder = hierarchy.initialFirstResponder
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func cancelOperation(_ sender: Any?) {
    closeDialog(shouldQuit: false)
  }
}

private extension MacosExitDialog {
  static func configure(_ panel: DialogPanel) {
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.isFloatingPanel = true
    panel.isMovable = true
    panel.isMovableByWindowBackground = true
    panel.level = .modalPanel
    panel.animationBehavior = .alertPanel
    panel.collectionBehavior = [.transient]
    panel.appearance = Constants.lightAppearance
  }

  func centerOverParentWindow() {
    guard let window else {
      return
    }

    if let parentWindow {
      window.center(over: parentWindow)
    } else {
      window.center()
    }
  }

  func closeDialog(shouldQuit: Bool) {
    self.shouldQuit = shouldQuit
    NSApp.stopModal()
  }
}

private extension MacosExitDialog {
  private func makeContentHierarchy(configuration: Configuration) -> ContentHierarchy {
    let rootView = makeRootView()
    let dialogContainer = makeDialogContainer()
    rootView.addSubview(dialogContainer)

    let overlayView = makeMaterialOverlay(in: dialogContainer)
    let layout = Layout()
    let dontQuitButton = addContent(
      to: overlayView,
      configuration: configuration,
      layout: layout
    )

    return ContentHierarchy(
      rootView: rootView,
      initialFirstResponder: dontQuitButton
    )
  }

  func makeRootView() -> DraggableView {
    let rootView = DraggableView(
      frame: NSRect(x: 0, y: 0, width: Properties.windowWidth, height: Properties.windowHeight)
    )
    rootView.wantsLayer = true
    rootView.layer?.backgroundColor = NSColor.clear.cgColor
    return rootView
  }

  func makeDialogContainer() -> DraggableView {
    let dialogContainer = DraggableView(
      frame: NSRect(
        x: Properties.shadowInset,
        y: Properties.shadowInset,
        width: Properties.dialogWidth,
        height: Properties.dialogHeight
      )
    )
    dialogContainer.wantsLayer = true
    dialogContainer.layer?.cornerRadius = Properties.cornerRadius
    dialogContainer.layer?.masksToBounds = false
    dialogContainer.layer?.backgroundColor = NSColor.clear.cgColor
    dialogContainer.layer?.shadowColor = Constants.dialogShadowColor.cgColor
    dialogContainer.layer?.shadowOpacity = Constants.dialogShadowOpacity
    dialogContainer.layer?.shadowRadius = Constants.dialogShadowRadius
    dialogContainer.layer?.shadowOffset = Constants.dialogShadowOffset
    dialogContainer.layer?.shadowPath = roundedPath(
      in: dialogContainer.bounds,
      cornerRadius: Properties.cornerRadius
    )
    return dialogContainer
  }

  func makeMaterialOverlay(in contentView: NSView) -> NSView {
    let materialView = DraggableVisualEffectView(frame: contentView.bounds)
    materialView.autoresizingMask = [.width, .height]
    materialView.material = .hudWindow
    materialView.blendingMode = .behindWindow
    materialView.state = .active
    materialView.wantsLayer = true
    materialView.layer?.cornerRadius = Properties.cornerRadius
    materialView.layer?.masksToBounds = true
    contentView.addSubview(materialView)

    let overlayView = DraggableView(frame: contentView.bounds)
    overlayView.autoresizingMask = [.width, .height]
    overlayView.wantsLayer = true
    overlayView.layer?.cornerRadius = Properties.cornerRadius
    overlayView.layer?.masksToBounds = true
    overlayView.layer?.backgroundColor = Constants.overlayBackgroundColor.cgColor
    overlayView.layer?.borderColor = Constants.dialogBorderColor.cgColor
    overlayView.layer?.borderWidth = Properties.borderWidth
    contentView.addSubview(overlayView)

    return overlayView
  }

  private func addContent(
    to contentView: NSView,
    configuration: Configuration,
    layout: Layout
  ) -> DialogButton {
    contentView.addSubview(makeIconView(frame: layout.iconFrame))
    contentView.addSubview(makeTitleLabel(title: configuration.title, frame: layout.titleFrame))
    contentView.addSubview(makeMessageLabel(message: configuration.message, frame: layout.messageFrame))

    let quitButton = makeButton(
      title: configuration.quitButtonText,
      frame: layout.quitButtonFrame,
      backgroundColor: Self.lightResolvedColor(.controlBackgroundColor),
      textColor: Self.lightResolvedColor(.labelColor),
      action: #selector(quitButtonPressed)
    )
    contentView.addSubview(quitButton)

    let dontQuitButton = makeButton(
      title: configuration.dontQuitButtonText,
      frame: layout.dontQuitButtonFrame,
      backgroundColor: .systemBlue,
      textColor: Constants.primaryButtonTextColor,
      action: #selector(dontQuitButtonPressed)
    )
    contentView.addSubview(dontQuitButton)

    return dontQuitButton
  }
}

private extension MacosExitDialog {
  func makeIconView(frame: NSRect) -> NSView {
    let iconShadowView = DraggableView(frame: frame)
    iconShadowView.wantsLayer = true
    iconShadowView.layer?.shadowColor = Constants.iconShadowColor.cgColor
    iconShadowView.layer?.shadowOpacity = Constants.iconShadowOpacity
    iconShadowView.layer?.shadowRadius = Constants.iconShadowRadius
    iconShadowView.layer?.shadowOffset = Constants.iconShadowOffset
    iconShadowView.layer?.shadowPath = roundedPath(
      in: iconShadowView.bounds,
      cornerRadius: Properties.iconCornerRadius
    )

    let iconView = DraggableImageView(frame: iconShadowView.bounds)
    iconView.image = NSImage(named: "ExitDialogIcon") ?? Self.makePlaceholderIcon()
    iconView.imageScaling = .scaleProportionallyUpOrDown
    iconShadowView.addSubview(iconView)

    return iconShadowView
  }

  func makeTitleLabel(title: String, frame: NSRect) -> NSTextField {
    let label = NSTextField(labelWithString: title)
    label.frame = frame
    label.alignment = .center
    label.font = Constants.titleFont
    label.textColor = Constants.titleTextColor
    label.lineBreakMode = .byTruncatingTail
    return label
  }

  func makeMessageLabel(message: String, frame: NSRect) -> NSTextField {
    let label = DraggableTextField(wrappingLabelWithString: message)
    label.frame = frame
    label.alignment = .center
    label.font = Constants.messageFont
    label.textColor = Constants.messageTextColor
    label.isSelectable = false
    label.maximumNumberOfLines = 2
    return label
  }

  func makeButton(
    title: String,
    frame: NSRect,
    backgroundColor: NSColor,
    textColor: NSColor,
    action: Selector
  ) -> DialogButton {
    let button = DialogButton(
      frame: frame,
      title: title,
      backgroundColor: backgroundColor,
      textColor: textColor,
      cornerRadius: Properties.buttonCornerRadius
    )
    button.target = self
    button.action = action
    return button
  }

  @objc func quitButtonPressed() {
    closeDialog(shouldQuit: true)
  }

  @objc func dontQuitButtonPressed() {
    closeDialog(shouldQuit: false)
  }
}

private extension MacosExitDialog {
  static func lightResolvedColor(_ color: NSColor) -> NSColor {
    guard let lightAppearance = Constants.lightAppearance else {
      return color
    }

    var resolvedColor = color
    lightAppearance.performAsCurrentDrawingAppearance {
      resolvedColor = NSColor(cgColor: color.cgColor) ?? color
    }
    return resolvedColor
  }

  static func makePlaceholderIcon() -> NSImage {
    let image = NSImage(size: NSSize(width: Properties.iconSize, height: Properties.iconSize))
    image.lockFocus()

    Constants.placeholderBackgroundColor.setFill()
    NSBezierPath(
      roundedRect: NSRect(
        x: 0,
        y: 0,
        width: Properties.iconSize,
        height: Properties.iconSize
      ),
      xRadius: Properties.iconCornerRadius,
      yRadius: Properties.iconCornerRadius
    ).fill()

    let circleInset = Properties.placeholderCircleInset
    let circleDiameter = Properties.iconSize - circleInset * 2
    Constants.placeholderAccentColor.setFill()
    NSBezierPath(
      ovalIn: NSRect(
        x: circleInset,
        y: circleInset,
        width: circleDiameter,
        height: circleDiameter
      )
    ).fill()

    Constants.placeholderBackgroundColor.setStroke()
    let checkPath = NSBezierPath()
    checkPath.lineWidth = Properties.placeholderCheckLineWidth
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

  func roundedPath(in rect: NSRect, cornerRadius: CGFloat) -> CGPath {
    NSBezierPath(
      roundedRect: rect,
      xRadius: cornerRadius,
      yRadius: cornerRadius
    ).cgPath
  }
}

private final class DialogPanel: NSPanel {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }
}

private final class DraggableView: NSView {
  override var mouseDownCanMoveWindow: Bool { true }
}

private final class DraggableVisualEffectView: NSVisualEffectView {
  override var mouseDownCanMoveWindow: Bool { true }
}

private final class DraggableTextField: NSTextField {
  override var mouseDownCanMoveWindow: Bool { true }
}

private final class DraggableImageView: NSImageView {
  override var mouseDownCanMoveWindow: Bool { true }
}

private final class DialogButton: NSControl {
  private enum KeyCode {
    static let enter: UInt16 = 36
    static let space: UInt16 = 49
    static let keypadEnter: UInt16 = 76
  }

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
    pressedColor = backgroundColor.blended(
      withFraction: DialogStyleConstants.buttonPressedOverlayFraction,
      of: .black
    ) ?? backgroundColor
    preferredCornerRadius = cornerRadius
    self.title = title
    self.textColor = textColor

    super.init(frame: frame)
    configureLayer()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func mouseDown(with event: NSEvent) {
    setPressedState(true)

    guard let mouseUpEvent = window?.nextEvent(matching: [.leftMouseUp]) else {
      setPressedState(false)
      return
    }

    setPressedState(false)
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
    makeAttributedTitle().draw(
      with: titleRect(),
      options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine]
    )
  }

  override func keyDown(with event: NSEvent) {
    switch event.keyCode {
    case KeyCode.enter, KeyCode.space, KeyCode.keypadEnter:
      sendAction(action, to: target)
    default:
      super.keyDown(with: event)
    }
  }

  private func configureLayer() {
    wantsLayer = true
    layer?.backgroundColor = normalColor.cgColor
    layer?.cornerRadius = Self.clampedCornerRadius(preferredCornerRadius, for: bounds.size)
    layer?.masksToBounds = true
  }

  private func setPressedState(_ isPressed: Bool) {
    layer?.backgroundColor = (isPressed ? pressedColor : normalColor).cgColor
  }

  private func makeAttributedTitle() -> NSAttributedString {
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = .center
    paragraphStyle.lineBreakMode = .byTruncatingTail

    return NSAttributedString(
      string: title,
      attributes: [
        .font: DialogStyleConstants.buttonFont,
        .foregroundColor: textColor,
        .paragraphStyle: paragraphStyle,
      ]
    )
  }

  private func titleRect() -> NSRect {
    let attributedTitle = makeAttributedTitle()
    let insetBounds = bounds.insetBy(dx: DialogStyleProperties.buttonTitleInset, dy: 0)
    let titleSize = attributedTitle.boundingRect(
      with: NSSize(width: insetBounds.width, height: .greatestFiniteMagnitude),
      options: [.usesLineFragmentOrigin, .usesFontLeading]
    ).size
    let titleHeight = ceil(titleSize.height)

    return NSRect(
      x: insetBounds.minX,
      y: bounds.midY - titleHeight / 2,
      width: insetBounds.width,
      height: titleHeight
    )
  }

  private static func clampedCornerRadius(_ cornerRadius: CGFloat, for size: NSSize) -> CGFloat {
    min(cornerRadius, min(size.width, size.height) / 2)
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
