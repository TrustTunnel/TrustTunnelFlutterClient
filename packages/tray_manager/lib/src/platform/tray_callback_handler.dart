import 'package:tray_manager/src/platform/tray_callback_api.dart';

/// {@template tray_callback_handler}
/// Default implementation of [TrayCallbackApi] that forwards clicks to a callback.
/// {@endtemplate}
final class TrayCallbackHandler implements TrayCallbackApi {
  @override
  final void Function(String id) onMenuItemClicked;

  const TrayCallbackHandler(this.onMenuItemClicked);
}
