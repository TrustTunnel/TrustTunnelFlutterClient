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
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Theme(
      data: context.theme.copyWith(
        dropdownMenuTheme: enabled
            ? context.theme.extension<CustomDropdownMenuTheme>()!.enabled
            : context.theme.extension<CustomDropdownMenuTheme>()!.disabled,
      ),
      child: DropdownMenu<T>(
        initialSelection: value,
        label: Text(labelText),
        enabled: enabled,
        expandedInsets: expanded ? EdgeInsets.zero : null,
        onSelected: onChanged,
        errorText: errorText,
        hintText: labelText,
        requestFocusOnTap: false,
        dropdownMenuEntries: values
            .map(
              (e) => DropdownMenuEntry<T>(
                value: e,
                label: toText(e),
                labelWidget: toWidget?.call(e),
              ),
            )
            .toList(),
      ),
    ),
  );
}
