import 'package:quick_actions/quick_actions.dart';

class SamsungRoutineHandler {
  static final QuickActions _quickActions = const QuickActions();

  // We pass a callback function so this file doesn't need to know 
  // exactly how TrustTunnel's internal VPN logic works.
  static void init(Function onTriggered) {
    // 1. Listen for the shortcut being triggered
    _quickActions.initialize((String shortcutType) {
      if (shortcutType == 'connect_work_server') {
        onTriggered(); // Run the VPN connection logic passed from main.dart
      }
    });

    // 2. Register the shortcut with the Android OS
    _quickActions.setShortcutItems(<ShortcutItem>[
      const ShortcutItem(
        type: 'connect_work_server',
        localizedTitle: 'Connect to Work Server',
        icon: 'ic_launcher', // This uses the default app icon
      ),
    ]);
  }
}