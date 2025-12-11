import 'package:flutter/material.dart';
import 'package:vpn/common/extensions/context_extensions.dart';
import 'package:vpn/view/common/custom_radio.dart';
import 'package:vpn/view/custom_icon.dart';

class CustomRadioListTile<T> extends StatelessWidget {
  final T value;
  final T groupValue;
  final String? title;
  final Color? titleColor;
  final Widget? titleWidget;
  final String? subTitle;
  final String? error;
  final IconData? iconPath;
  final Color? iconColor;
  final ValueChanged<T?>? onChanged;
  final bool enabled;
  const CustomRadioListTile({
    super.key,
    required this.value,
    required this.groupValue,
    required this.title,
    required this.onChanged,
    this.iconPath,
    this.subTitle,
    this.error,
    this.enabled = true,
    this.iconColor,
    this.titleColor,
  }) : titleWidget = null;

  const CustomRadioListTile.titleWidget({
    super.key,
    required this.value,
    required this.groupValue,
    required this.titleWidget,
    required this.onChanged,
    this.iconPath,
    this.subTitle,
    this.error,
    this.enabled = true,
    this.iconColor,
    this.titleColor,
  }) : title = null;

  @override
  Widget build(BuildContext context) {
    final gestureEnabled = onChanged != null && enabled;

    final titleTextStyle = context.textTheme.bodyLarge?.copyWith(
      color: titleColor ?? (gestureEnabled ? null : context.colors.neutralLight),
    );
    final bodyTextStyle = context.textTheme.bodyMedium?.copyWith(
      color: gestureEnabled ? null : context.colors.neutralLight,
    );

    return InkWell(
      onTap: gestureEnabled ? () => onChanged?.call(value) : null,
      child: Ink(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomRadio<T>(
                value: value,
                groupValue: groupValue,
                onChanged: onChanged != null ? (_) => onChanged?.call(value) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: title != null
                          ? Text(
                              title!,
                              style: titleTextStyle,
                            )
                          : titleWidget!,
                    ),
                    if (subTitle != null)
                      Text(
                        subTitle!,
                        style: bodyTextStyle,
                      ),
                    if (error != null)
                      Text(
                        error!,
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: context.colors.error,
                        ),
                      ),
                  ],
                ),
              ),
              if (iconPath != null) ...[
                const SizedBox(width: 16),
                CustomIcon.medium(
                  icon: iconPath!,
                  color: iconColor,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
