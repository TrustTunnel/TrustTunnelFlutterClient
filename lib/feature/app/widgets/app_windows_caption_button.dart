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

  Set<WidgetState> get _widgetStates => {
    if (widget.isHovered) WidgetState.hovered,
    if (widget.isPressed) WidgetState.pressed,
    if (!widget.windowState.active) WidgetState.disabled,
  };

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
    final foregroundColor = widget.windowState.highContrast
        ? widget.windowState.captionForegroundColor
        : context.colors.windowsSystemTitleBarTitle;
    final isCloseButton = widget.buttonType == WindowsCaptionButton.close;

    final backgroundColor = _getBackgroundColor(
      isCloseButton: isCloseButton,
      defaultColor: context.colors.transparent,
    );
    final iconColor = _getIconColor(
      isCloseButton: isCloseButton,
      defaultColor: foregroundColor,
    );

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
              color: backgroundColor.resolve(_widgetStates),
              border: _showFocusHighlight ? Border.all(color: foregroundColor) : null,
            ),
            child: Center(
              child: AppWindowsCaptionIcon(
                button: widget.buttonType,
                maximized: widget.windowState.maximized,
                color: iconColor.resolve(_widgetStates),
              ),
            ),
          ),
        ),
      ),
    );
  }

  WidgetStateColor _getBackgroundColor({
    required bool isCloseButton,
    required Color defaultColor,
  }) => WidgetStateColor.resolveWith((states) {
    final pressed = states.contains(WidgetState.pressed);
    if (!pressed && !states.contains(WidgetState.hovered)) {
      return context.colors.transparent;
    }
    if (widget.windowState.highContrast) {
      return widget.windowState.highlightColor;
    }
    if (isCloseButton) {
      return pressed
          ? context.colors.windowsSystemTitleBarCloseButtonBackgroundPressed
          : context.colors.windowsSystemTitleBarCloseButtonBackgroundHover;
    }

    return pressed
        ? context.colors.windowsSystemTitleBarButtonBackgroundPressed
        : context.colors.windowsSystemTitleBarButtonBackgroundHover;
  });

  WidgetStateColor _getIconColor({
    required bool isCloseButton,
    required Color defaultColor,
  }) => WidgetStateColor.resolveWith((states) {
    final highlighted = states.contains(WidgetState.hovered) || states.contains(WidgetState.pressed);
    if (highlighted && widget.windowState.highContrast) {
      return widget.windowState.highlightTextColor;
    }
    if (highlighted && isCloseButton) {
      return context.colors.windowsSystemTitleBarCloseButtonForeground;
    }
    if (states.contains(WidgetState.disabled) && !widget.windowState.highContrast) {
      return context.colors.windowsSystemTitleBarTitleInactive;
    }

    return defaultColor;
  });

  void _activate() => unawaited(windowManager.invokeWindowsCaptionButton(widget.buttonType));

  void _setFocusHighlight(bool showFocusHighlight) {
    setState(() {
      _showFocusHighlight = showFocusHighlight;
    });
  }

  void _scheduleTooltip() {
    // Native non-client hover bypasses Flutter's MouseRegion, so Tooltip.waitDuration
    // cannot schedule this display. TooltipState only exposes immediate showing;
    // keep the cancellable delay here until Flutter provides a controller for it.
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
