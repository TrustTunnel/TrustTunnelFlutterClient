import 'package:flutter/material.dart';
import 'package:vpn/view/custom_icon.dart';

class CustomIconButton extends StatefulWidget {
  final IconData? icon;
  final IconData? selectedIcon;
  final Widget? iconWidget;
  final Widget? selectedIconWidget;

  final VoidCallback? onPressed;
  final double? height;
  final double? width;
  final double? padding;
  final String? tooltip;
  final Color? color;
  final bool? selected;

  const CustomIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.selected,
    this.height,
    this.width,
    this.padding,
    this.tooltip,
    this.color,
  }) : selectedIcon = null,
       iconWidget = null,
       selectedIconWidget = null;

  const CustomIconButton.square({
    super.key,
    required this.icon,
    this.onPressed,
    required double size,
    this.padding,
    this.tooltip,
    this.color,
    this.selected,
  }) : height = size,
       width = size,
       selectedIcon = null,
       iconWidget = null,
       selectedIconWidget = null;

  const CustomIconButton.toggleable({
    super.key,
    required this.icon,
    required this.selectedIcon,
    this.onPressed,
    this.height,
    this.width,
    this.padding,
    this.tooltip,
    this.color,
    this.selected,
  }) : iconWidget = null,
       selectedIconWidget = null;

  const CustomIconButton.custom({
    super.key,
    required this.iconWidget,
    this.onPressed,
    this.selectedIconWidget,
    this.padding,
  }) : color = null,
       width = null,
       height = null,
       tooltip = null,
       icon = null,
       selectedIcon = null,
       selected = false;

  @override
  State<CustomIconButton> createState() => _CustomIconButtonState();
}

class _CustomIconButtonState extends State<CustomIconButton> {
  late bool _isSelected;

  @override
  void initState() {
    super.initState();
    _isSelected = widget.selected ?? false;
  }

  @override
  void didUpdateWidget(CustomIconButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != null) {
      _isSelected = widget.selected!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIcon = _getSelectedIcon(context);

    return IconButton(
      onPressed: widget.onPressed != null
          ? () {
              widget.onPressed!();
              if (widget.selected == null) {
                setState(() => _isSelected = !_isSelected);
              }
            }
          : null,
      tooltip: widget.tooltip ?? '',
      // TODO: Check padding
      // Konstantin Gorynin <k.gorynin@adguard.com>, 29 August 2025
      padding: EdgeInsets.all(widget.padding ?? 8),
      isSelected: _isSelected,
      selectedIcon: selectedIcon,
      icon: _getIcon(context),
    );
  }

  Widget _getIcon(BuildContext context) {
    if (widget.iconWidget != null) {
      return widget.iconWidget!;
    }

    return CustomIcon.medium(
      icon: widget.icon!,
      color: widget.color,
    );
  }

  Widget? _getSelectedIcon(BuildContext context) {
    if (widget.selectedIconWidget != null) {
      return widget.selectedIconWidget!;
    }
    if (widget.selectedIcon == null) {
      return null;
    }

    return CustomIcon(
      icon: widget.selectedIcon!,
      size: widget.width ?? widget.height,
      color: widget.color,
    );
  }
}
