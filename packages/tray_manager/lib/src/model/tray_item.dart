/// {@template tray_item}
/// Base class for all tray menu items.
///
/// Subclasses:
/// - [TrayButton] - clickable menu item with optional submenu
/// - [TraySeparator] - horizontal divider line
/// - [TrayStatus] - non-clickable text label
/// {@endtemplate}
abstract class TrayItem {
  const TrayItem();
}
