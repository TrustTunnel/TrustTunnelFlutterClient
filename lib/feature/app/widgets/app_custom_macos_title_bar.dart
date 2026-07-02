import 'dart:async';

import 'package:flutter/material.dart';
import 'package:trusttunnel/common/assets/font_families.dart';
import 'package:trusttunnel/common/constants/app_constants.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/utils/macos_app_window_utils.dart';
import 'package:window_manager/window_manager.dart';

class AppCustomMacOSTitleBar extends StatefulWidget {
  const AppCustomMacOSTitleBar({super.key});

  @override
  State<AppCustomMacOSTitleBar> createState() => _AppCustomMacOSTitleBarState();
}

class _AppCustomMacOSTitleBarState extends State<AppCustomMacOSTitleBar> with WindowListener {
  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    unawaited(windowManager.setHideTitleBarOnExitFullScreen(true));
    unawaited(_syncFullScreenState());
  }

  @override
  Widget build(BuildContext context) {
    if (_isFullScreen) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onDoubleTap: _toggleZoom,
      onPanStart: (_) => windowManager.startDragging(),
      child: ColoredBox(
        color: context.colors.appSystemTitleBarBackground,
        child: SizedBox(
          height: 28,
          child: Center(
            child: Text(
              AppConstants.appName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.colors.appSystemTitleBarTitle,
                decoration: TextDecoration.none,
                fontFamily: FontFamilies.cupertinoSystemText,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void onWindowWillEnterFullScreen() {
    unawaited(windowManager.setTitleBarStyle(TitleBarStyle.normal));
    _setFullScreen(true);
  }

  @override
  void onWindowWillLeaveFullScreen() {
    unawaited(windowManager.setTitleBarStyle(TitleBarStyle.hidden));
    _setFullScreen(false);
  }

  @override
  void onWindowClose() {
    unawaited(MacOSAppWindowUtils.hideMainWindow());
  }

  Future<void> _syncFullScreenState() async {
    final isFullScreen = await windowManager.isFullScreen();
    _setFullScreen(isFullScreen);
  }

  Future<void> _toggleZoom() async {
    final isMaximized = await windowManager.isMaximized();
    if (isMaximized) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  void _setFullScreen(bool isFullScreen) {
    if (!mounted || _isFullScreen == isFullScreen) {
      return;
    }

    setState(() {
      _isFullScreen = isFullScreen;
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }
}
