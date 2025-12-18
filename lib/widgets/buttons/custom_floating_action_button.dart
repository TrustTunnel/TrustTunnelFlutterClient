import 'package:flutter/material.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/widgets/custom_icon.dart';
import 'package:trusttunnel/widgets/hover_theme_provider.dart';

enum CustomFloatingActionButtonType {
  extended,
  standart,
  small,
  large,
}

class CustomFloatingActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final CustomFloatingActionButtonType type;
  final String? label;

  const CustomFloatingActionButton({
    super.key,
    required this.icon,
    required this.onPressed,
  }) : type = CustomFloatingActionButtonType.standart,
       label = null;

  const CustomFloatingActionButton.extended({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.label,
  }) : type = CustomFloatingActionButtonType.extended;

  const CustomFloatingActionButton.small({
    super.key,
    required this.icon,
    required this.onPressed,
  }) : type = CustomFloatingActionButtonType.small,
       label = null;

  const CustomFloatingActionButton.large({
    super.key,
    required this.icon,
    required this.onPressed,
  }) : type = CustomFloatingActionButtonType.large,
       label = null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).floatingActionButtonTheme;
    final iconWidget = CustomIcon.medium(
      icon: icon,
      color: theme.foregroundColor ?? context.colors.accent,
    );

    final Widget button = switch (type) {
      CustomFloatingActionButtonType.standart => FloatingActionButton(
        onPressed: onPressed,
        child: iconWidget,
      ),
      CustomFloatingActionButtonType.extended =>
        label != null
            ? FloatingActionButton.extended(
                onPressed: onPressed,
                icon: iconWidget,
                label: Text(
                  label!,
                  style: context.theme.textTheme.labelLarge?.copyWith(color: theme.foregroundColor),
                ),
              )
            : FloatingActionButton(
                onPressed: onPressed,
                child: iconWidget,
              ),
      CustomFloatingActionButtonType.small => FloatingActionButton.small(
        onPressed: onPressed,
        child: iconWidget,
      ),
      CustomFloatingActionButtonType.large => FloatingActionButton.large(
        onPressed: onPressed,
        child: iconWidget,
      ),
    };

    return HoverThemeProvider(
      child: button,
    );
  }
}
