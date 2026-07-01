import 'package:flutter/foundation.dart';

/// {@template tray_icon}
/// Represents a tray icon as PNG bytes.
///
/// Set [isMonochrome] to `true` for template icons on macOS that adapt
/// to the system's light/dark appearance.
/// {@endtemplate}
class TrayIcon {
  /// PNG image data for the icon.
  final Uint8List bytes;

  /// If true, icon is treated as a template on macOS (adapts to light/dark).
  final bool isMonochrome;

  const TrayIcon(
    this.bytes, {
    this.isMonochrome = false,
  });
}
