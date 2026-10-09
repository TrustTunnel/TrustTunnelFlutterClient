import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/feature/app/widgets/app_windows_caption_icon.dart';
import 'package:window_manager/window_manager.dart';

class AppWindowsCaptionButton extends StatelessWidget {
  final WindowsCaptionButton buttonType;
  final WindowsTitleBarState windowState;
  final double height;
  final double width;

  const AppWindowsCaptionButton({
    required this.buttonType,
    required this.windowState,
    required this.height,
    required this.width,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final label = switch (buttonType) {
      WindowsCaptionButton.minimize => context.ln.windowMinimize,
      WindowsCaptionButton.maximize => windowState.maximized ? context.ln.windowRestore : context.ln.windowMaximize,
      WindowsCaptionButton.close => context.ln.windowClose,
    };

    return Tooltip(
      message: label,
      triggerMode: TooltipTriggerMode.manual,
      excludeFromSemantics: true,
      child: _CaptionButtonControl(
        buttonType: buttonType,
        windowState: windowState,
        height: height,
        width: width,
        label: label,
      ),
    );
  }
}

class _CaptionButtonControl extends StatefulWidget {
  final WindowsCaptionButton buttonType;
  final WindowsTitleBarState windowState;
  final double height;
  final double width;
  final String label;

  const _CaptionButtonControl({
    required this.buttonType,
    required this.windowState,
    required this.height,
    required this.width,
    required this.label,
  });

  bool get isHovered => windowState.hovered == buttonType;

  bool get isPressed => windowState.pressed == buttonType && isHovered;

  bool get shouldShowTooltip => isHovered && windowState.pressed == null && windowState.active;

  @override
  State<_CaptionButtonControl> createState() => _CaptionButtonControlState();
}

class _CaptionButtonControlState extends State<_CaptionButtonControl> {
  bool _showFocusHighlight = false;
  Timer? _tooltipTimer;

  @override
  void initState() {
    super.initState();
    if (widget.shouldShowTooltip) {
      _scheduleTooltip();
    }
  }

  @override
  void didUpdateWidget(covariant _CaptionButtonControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shouldShowTooltip == oldWidget.shouldShowTooltip) {
      return;
    }

    _tooltipTimer?.cancel();
    if (widget.shouldShowTooltip) {
      _scheduleTooltip();
    } else {
      Tooltip.dismissAllToolTips();
    }
  }

  @override
  Widget build(BuildContext context) {
    final foreground = widget.windowState.highContrast
        ? widget.windowState.captionForegroundColor
        : context.colors.windowsSystemTitleBarTitle;
    final highlighted = widget.isHovered || widget.isPressed;
    final isCloseButton = widget.buttonType == WindowsCaptionButton.close;
    final Color background;
    final Color iconColor;

    if (!highlighted) {
      background = context.colors.transparent;
    } else if (widget.windowState.highContrast) {
      background = widget.windowState.highlightColor;
    } else if (isCloseButton) {
      background = widget.isPressed
          ? context.colors.windowsSystemTitleBarCloseButtonBackgroundPressed
          : context.colors.windowsSystemTitleBarCloseButtonBackgroundHover;
    } else {
      background = widget.isPressed
          ? context.colors.windowsSystemTitleBarButtonBackgroundPressed
          : context.colors.windowsSystemTitleBarButtonBackgroundHover;
    }

    if (highlighted && widget.windowState.highContrast) {
      iconColor = widget.windowState.highlightTextColor;
    } else if (highlighted && isCloseButton) {
      iconColor = context.colors.windowsSystemTitleBarCloseButtonForeground;
    } else {
      iconColor = widget.windowState.active || widget.windowState.highContrast
          ? foreground
          : context.colors.windowsSystemTitleBarTitleInactive;
    }

    return Semantics(
      button: true,
      label: widget.label,
      onTap: _activate,
      child: FocusableActionDetector(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _activate()),
        },
        onShowFocusHighlight: _setFocusHighlight,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: background,
              border: _showFocusHighlight ? Border.all(color: foreground) : null,
            ),
            child: Center(
              child: AppWindowsCaptionIcon(
                button: widget.buttonType,
                maximized: widget.windowState.maximized,
                color: iconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _activate() => unawaited(windowManager.invokeWindowsCaptionButton(widget.buttonType));

  void _setFocusHighlight(bool showFocusHighlight) {
    setState(() {
      _showFocusHighlight = showFocusHighlight;
    });
  }

  void _scheduleTooltip() {
    // Non-client hover does not reach Flutter's MouseRegion. This state is
    // already below Tooltip, so no GlobalKey is needed to display it.
    _tooltipTimer = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) {
        return;
      }

      context.findAncestorStateOfType<TooltipState>()?.ensureTooltipVisible();
    });
  }

  @override
  void dispose() {
    _tooltipTimer?.cancel();
    super.dispose();
  }
}
