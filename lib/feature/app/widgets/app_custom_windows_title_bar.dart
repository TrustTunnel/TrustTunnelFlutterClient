import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:trusttunnel/common/assets/font_families.dart';
import 'package:trusttunnel/common/constants/app_constants.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/feature/app/controller/windows_app_window_controller.dart';
import 'package:trusttunnel/feature/app/widgets/app_windows_caption_button.dart';
import 'package:window_manager/window_manager.dart';

class AppCustomWindowsTitleBar extends StatefulWidget {
  final double titleBarHeight;
  final double windowsCaptionButtonsWidth;

  const AppCustomWindowsTitleBar({
    super.key,
    this.titleBarHeight = 32.0,
    this.windowsCaptionButtonsWidth = 46.0,
  });

  @override
  State<AppCustomWindowsTitleBar> createState() => _AppCustomWindowsTitleBarState();
}

class _AppCustomWindowsTitleBarState extends State<AppCustomWindowsTitleBar> with WindowListener {
  static const _mainWindowChannel = MethodChannel('trusttunnel/windows_main_window');

  WindowsTitleBarState _windowState = const WindowsTitleBarState();
  Size? _titleBarSize;
  bool _regionsUpdateScheduled = false;
  bool _launchCompleted = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    unawaited(_syncWindowState());
  }

  @override
  Widget build(BuildContext context) {
    final foregroundTextColor = _windowState.highContrast
        ? _windowState.captionForegroundColor
        : _windowState.active
        ? context.colors.windowsSystemTitleBarTitle
        : context.colors.windowsSystemTitleBarTitleInactive;

    return LayoutBuilder(
      builder: (context, constraints) {
        _scheduleRegionsUpdate(Size(constraints.maxWidth, widget.titleBarHeight));

        return ColoredBox(
          color: _windowState.highContrast
              ? _windowState.captionBackgroundColor
              : context.colors.windowsSystemTitleBarBackground,
          child: SizedBox(
            height: widget.titleBarHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              textDirection: TextDirection.ltr,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16, top: 8),
                    child: Text(
                      AppConstants.appName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        color: foregroundTextColor,
                        decoration: TextDecoration.none,
                        fontFamily: _windowState.fontFamily,
                        fontFamilyFallback: const [FontFamilies.segoeUiVariable, FontFamilies.segoeUi],
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        height: 16 / 12,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
                for (final buttonType in WindowsCaptionButton.values)
                  AppWindowsCaptionButton(
                    buttonType: buttonType,
                    windowState: _windowState,
                    height: widget.titleBarHeight,
                    width: widget.windowsCaptionButtonsWidth,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void onWindowsTitleBarStateChanged(WindowsTitleBarState state) {
    if (!mounted) {
      return;
    }

    setState(() {
      _windowState = state;
    });
  }

  Future<void> _syncWindowState() async {
    try {
      final state = await windowManager.getWindowsTitleBarState();
      onWindowsTitleBarStateChanged(state);
    } catch (error, stackTrace) {
      // Report without rethrowing: the default caption state is sufficient for startup.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'Windows title bar',
        ),
      );
    }
  }

  /// Schedules the regions update for the next frame.
  void _scheduleRegionsUpdate(Size size) {
    if (_titleBarSize == size || size.width <= 0) {
      return;
    }

    _titleBarSize = size;
    if (_regionsUpdateScheduled) {
      return;
    }

    _regionsUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _regionsUpdateScheduled = false;
      if (mounted) {
        unawaited(_updateRegions(_titleBarSize!));
      }
    });
  }

  /// In our implementation, Flutter is responsible for drawing the title bar,
  /// while the native code handles mouse events in the window's title bar.
  /// That's why we need to pass the region map separately so that Windows understands what exactly is under the mouse pointer.
  Future<void> _updateRegions(Size size) async {
    try {
      // This shell is at the top of the Flutter view. All three buttons have the
      // same fixed width, so their rectangles follow directly from the layout.
      await windowManager.setWindowsTitleBarRegions(
        WindowsTitleBarRegions(
          viewWidth: size.width,
          drag: Offset.zero & size,
          minimize: Rect.fromLTWH(
            size.width - widget.windowsCaptionButtonsWidth * 3,
            0,
            widget.windowsCaptionButtonsWidth,
            size.height,
          ),
          maximize: Rect.fromLTWH(
            size.width - widget.windowsCaptionButtonsWidth * 2,
            0,
            widget.windowsCaptionButtonsWidth,
            size.height,
          ),
          close: Rect.fromLTWH(
            size.width - widget.windowsCaptionButtonsWidth,
            0,
            widget.windowsCaptionButtonsWidth,
            size.height,
          ),
        ),
      );
      if (!mounted || _launchCompleted) {
        return;
      }

      await _mainWindowChannel.invokeMethod<void>('completeLaunch');
      _launchCompleted = true;
    } catch (error, stackTrace) {
      if (!_launchCompleted) {
        await WindowsAppWindowController.failLaunch(error, stackTrace);
      } else {
        // Launch already succeeded; report the update failure and keep the app running.
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'Windows title bar',
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }
}
