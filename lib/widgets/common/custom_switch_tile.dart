import 'package:flutter/material.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';

class CustomSwitchTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Color? subtitleColor;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const CustomSwitchTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: context.textTheme.bodyLarge,
              ),
              if (subtitle != null)
                Visibility(
                  visible: subtitle != null,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: Text(
                    subtitle ?? ' ',
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: subtitleColor,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 16, left: 16),
          child: Switch(
            value: value,
            onChanged: onChanged,
          ),
        ),
      ],
    ),
  );
}
