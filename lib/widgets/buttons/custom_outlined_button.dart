import 'package:flutter/material.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/extensions/theme_extensions.dart';
import 'package:trusttunnel/widgets/custom_icon.dart';
import 'package:trusttunnel/widgets/hover_theme_provider.dart';

class CustomOutlinedButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String label;

  const CustomOutlinedButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
  });

  @override
  State<CustomOutlinedButton> createState() => _OutlinedButtonSvgState();
}

class _OutlinedButtonSvgState extends State<CustomOutlinedButton> {
  late final _statesController = WidgetStatesController();

  @override
  Widget build(BuildContext context) => Theme(
    data: context.theme.copyWith(
      outlinedButtonTheme: context.theme.extension<CustomOutlinedButtonTheme>()!.iconButton,
    ),
    child: HoverThemeProvider(
      child: OutlinedButton.icon(
        onPressed: widget.onPressed,
        label: Text(widget.label),
        statesController: _statesController,
        icon: ValueListenableBuilder(
          valueListenable: _statesController,
          builder: (context, value, child) => CustomIcon.medium(
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
