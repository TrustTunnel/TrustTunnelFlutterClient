import 'package:flutter/material.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/extensions/theme_extensions.dart';

class CustomDropdownMenu<T> extends StatelessWidget {
  final bool expanded;
  final T value;
  final List<T> values;
  final String Function(T item) toText;
  final String labelText;
  final String? errorText;
  final bool enabled;
  final EdgeInsets padding;
  final ValueChanged<T?>? onChanged;

  final Widget? Function(T item)? toWidget;

  const CustomDropdownMenu({
    super.key,
    required this.value,
    required this.values,
    required this.toText,
    required this.labelText,
    required this.onChanged,
    this.toWidget,
    this.enabled = true,
    this.padding = EdgeInsets.zero,
    this.errorText,
  }) : expanded = false;

  const CustomDropdownMenu.expanded({
    super.key,
    required this.value,
    required this.values,
    required this.labelText,
    required this.onChanged,
    required this.toText,
    this.toWidget,
    this.enabled = true,
    this.padding = EdgeInsets.zero,
    this.errorText,
  }) : expanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final customTheme = theme.extension<CustomDropdownMenuTheme>()!;
    final menuTheme = enabled ? customTheme.enabled : customTheme.disabled;
    final menuOverlayColor = MenuButtonTheme.of(context).style?.overlayColor;

    return Padding(
      padding: padding,
      // The popup captures this theme and uses InkWell instead of MenuItemButton.
      child: Theme(
        data: theme.copyWith(
          hoverColor: menuOverlayColor?.resolve({WidgetState.hovered}) ?? theme.hoverColor,
          focusColor: menuOverlayColor?.resolve({WidgetState.focused}) ?? theme.focusColor,
        ),
        // The popup route handles Back before the enclosing form or dialog.
        child: DropdownButtonFormField<T>(
          initialValue: values.contains(value) ? value : null,
          isExpanded: expanded,
          onChanged: enabled ? onChanged : null,
          style: menuTheme.textStyle,
          dropdownColor: menuTheme.menuStyle?.backgroundColor?.resolve({}),
          iconEnabledColor: theme.iconTheme.color,
          iconDisabledColor: menuTheme.textStyle?.color,
          hint: Text(labelText),
          decoration: InputDecoration(
            labelText: labelText,
            errorText: errorText,
            enabled: enabled,
          ).applyDefaults(menuTheme.inputDecorationTheme ?? theme.inputDecorationTheme),
          selectedItemBuilder: (_) => values
              .map(
                (item) => Text(toText(item), style: menuTheme.textStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
              )
              .toList(),
          items: values
              .map(
                (item) => DropdownMenuItem<T>(
                  value: item,
                  child: toWidget?.call(item) ?? Text(toText(item)),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
