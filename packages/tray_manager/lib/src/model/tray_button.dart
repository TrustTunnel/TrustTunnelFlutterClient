import 'package:flutter/foundation.dart';
import 'package:tray_manager/src/model/tray_icon.dart';
import 'package:tray_manager/src/model/tray_item.dart';

/// {@template tray_button}
/// A clickable menu item in the system tray context menu.
///
/// Can have an optional [icon], [onTap] callback, and nested [children] for submenus.
/// Use [isEnabled] to disable the item and [isChecked] to show a checkmark.
/// {@endtemplate}
final class TrayButton extends TrayItem {
  /// Display text for the menu item.
  final String title;

  /// Whether the item is clickable. Disabled items appear grayed out.
  final bool isEnabled;

  /// Whether to show a checkmark next to the item.
  final bool isChecked;

  /// Optional icon displayed next to the title.
  final TrayIcon? icon;

  /// Nested menu items for creating submenus.
  final List<TrayItem> children;

  /// Callback invoked when the item is clicked.
  final VoidCallback? onTap;

  const TrayButton({
    required this.title,
    this.isEnabled = true,
    this.isChecked = false,
    this.icon,
    this.onTap,
    this.children = const [],
  });
}
