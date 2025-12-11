import 'package:flutter/material.dart';
import 'package:vpn/common/extensions/context_extensions.dart';
import 'package:vpn/common/extensions/theme_extensions.dart';
import 'package:vpn/view/custom_icon.dart';
import 'package:vpn/view/hover_theme_provider.dart';

class CustomElevatedButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String label;

  const CustomElevatedButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Theme(
    data: context.theme.copyWith(
      elevatedButtonTheme: context.theme.extension<CustomElevatedButtonTheme>()!.iconButton,
    ),
    child: HoverThemeProvider(
      child: ElevatedButton.icon(
        onPressed: onPressed,
        label: Text(label),
        icon: CustomIcon.medium(
          icon: icon,
        ),
      ),
    ),
  );
}
