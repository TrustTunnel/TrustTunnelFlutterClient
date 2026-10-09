import 'package:flutter/material.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';

class CustomCheckboxListTile extends StatelessWidget {
  final bool value;
  final Widget title;
  final EdgeInsetsGeometry padding;
  final Widget? trailing;
  final ValueChanged<bool>? onChanged;

  const CustomCheckboxListTile({
    super.key,
    required this.value,
    required this.title,
    required this.onChanged,
    this.padding = const EdgeInsets.all(16),
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;

    return Material(
      color: context.colors.transparent,
      child: InkWell(
        onTap: enabled ? () => onChanged?.call(!value) : null,
        child: Padding(
          padding: padding,
          child: Row(
            children: [
              IgnorePointer(
                child: SizedBox.square(
                  dimension: 18,
                  child: Checkbox(
                    value: value,
                    onChanged: enabled ? (_) {} : null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: title,
                ),
              ),
              trailing ?? const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }
}
