import 'package:flutter/material.dart';
import 'package:vpn/common/extensions/context_extensions.dart';
import 'package:vpn/common/extensions/theme_extensions.dart';
import 'package:vpn/view/custom_icon.dart';
import 'package:vpn/view/hover_theme_provider.dart';

class CustomTextButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String label;

  const CustomTextButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
  });

  @override
  State<CustomTextButton> createState() => _TextButtonSvgState();
}

class _TextButtonSvgState extends State<CustomTextButton> {
  late final _statesController = WidgetStatesController();

  @override
  Widget build(BuildContext context) => Theme(
    data: context.theme.copyWith(
      textButtonTheme: context.theme.extension<CustomTextButtonTheme>()!.iconButton,
    ),
    child: HoverThemeProvider(
      child: TextButton.icon(
        onPressed: widget.onPressed,
        label: Text(widget.label),
        statesController: _statesController,
        icon: ValueListenableBuilder(
          valueListenable: _statesController,
          builder: (context, value, child) => CustomIcon.small(
            icon: widget.icon,
          ),
        ),
      ),
    ),
  );

  @override
  void dispose() {
    _statesController.dispose();
    super.dispose();
  }
}
