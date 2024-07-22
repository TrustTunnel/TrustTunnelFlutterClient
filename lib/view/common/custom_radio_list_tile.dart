import 'package:flutter/material.dart';
import 'package:vpn/common/extensions/common_extensions.dart';
import 'package:vpn/common/extensions/context_extensions.dart';
import 'package:vpn/view/custom_svg_picture.dart';

class CustomRadioListTile<T> extends StatelessWidget {
  final T type;
  final T currentValue;
  final String? title;
  final Widget? titleWidget;

  final String? subTitle;
  final String? iconPath;
  final ValueChanged<T?> onChanged;
  final bool showVerticalDivider;
  final Widget? trailing;
  final VoidCallback? onTrailingIconTap;
  final bool showRadioButton;
  final bool enableTap;

  const CustomRadioListTile({
    super.key,
    required this.type,
    required this.currentValue,
    required this.title,
    required this.onChanged,
    this.iconPath,
    this.subTitle,
    this.onTrailingIconTap,
    this.trailing,
    this.showVerticalDivider = true,
    this.showRadioButton = true,
    this.enableTap = true,
  }) : titleWidget = null;

  const CustomRadioListTile.titleWidget({
    super.key,
    required this.type,
    required this.currentValue,
    required this.titleWidget,
    required this.onChanged,
    this.iconPath,
    this.subTitle,
    this.onTrailingIconTap,
    this.trailing,
    this.showVerticalDivider = true,
    this.showRadioButton = true,
    this.enableTap = true,
  }) : title = null;

  @override
  Widget build(BuildContext context) {
    const double iconSize = 24;

    return IntrinsicHeight(
      child: Row(
        children: [
          Flexible(
            fit: FlexFit.tight,
            child: InkWell(
              onTap: enableTap ? () => onChanged(type) : null,
              child: Ink(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (showRadioButton) ...[
                        SizedBox.square(
                          dimension: 24,
                          child: Radio<T>(
                            value: type,
                            splashRadius: 0,
                            groupValue: currentValue,
                            onChanged: (_) => onChanged(type),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: title != null
                                  ? Text(title!).labelLarge(context)
                                  : titleWidget!,
                            ),
                            if (subTitle != null) ...[
                              Text(
                                subTitle!,
                                style: context.textTheme.bodyMedium?.copyWith(
                                  color: context.colors.gray1,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (iconPath != null) ...[
                        const SizedBox(width: 16),
                        CustomSvgPicture(
                          icon: iconPath!,
                          size: iconSize,
                          color: context.colors.contrast1,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (trailing != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
              child: Row(
                children: [
                  if (showVerticalDivider) ...[
                    VerticalDivider(color: context.theme.dividerTheme.color),
                    const SizedBox(width: 16),
                  ],
                  trailing!,
                ],
              ),
            ),
        ],
      ),
    );
  }
}
