import 'package:flutter/material.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';

class CustomListTileSeparated extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTileTap;
  final bool showVerticalDivider;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;

  const CustomListTileSeparated({
    super.key,
    required this.title,
    this.onTileTap,
    this.trailing,
    this.showVerticalDivider = true,
    this.titleStyle,
    this.subtitle,
    this.subtitleStyle,
  });

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      children: [
        Flexible(
          fit: FlexFit.tight,
          child: InkWell(
            onTap: onTileTap,
            child: Ink(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: titleStyle ?? context.textTheme.bodyLarge,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: subtitleStyle ?? context.textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        if (showVerticalDivider)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: VerticalDivider(
              color: context.theme.dividerTheme.color,
            ),
          ),
        if (trailing != null)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: trailing!,
          ),
      ],
    ),
  );
}
