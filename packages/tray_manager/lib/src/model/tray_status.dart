import 'package:tray_manager/src/model/tray_item.dart';

/// {@template tray_status}
/// A non-clickable text label in the tray context menu.
///
/// Typically used to display status information like connection state.
/// {@endtemplate}
final class TrayStatus extends TrayItem {
  /// Display text for the status label.
  final String title;

  const TrayStatus({
    required this.title,
  });
}
