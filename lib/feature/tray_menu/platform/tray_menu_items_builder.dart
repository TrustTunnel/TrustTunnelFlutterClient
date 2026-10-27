import 'package:tray_manager/tray_manager.dart';
import 'package:trusttunnel/feature/tray_menu/model/tray_menu_data.dart';

/// Defines the platform-specific tray menu contents and layout.
abstract interface class TrayMenuItemsBuilder {
  List<TrayItem> build({
    required TrayMenuData data,
    required TrayMenuCallbacks callbacks,
  });
}
