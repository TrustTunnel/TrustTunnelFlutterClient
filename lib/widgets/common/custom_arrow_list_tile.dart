import 'package:flutter/material.dart';
import 'package:trusttunnel/common/assets/asset_icons.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/widgets/custom_icon.dart';

class CustomArrowListTile extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  final IconData trailingIcon;
  final Color? trailingIconColor;

  const CustomArrowListTile({
    super.key,
    required this.title,
    required this.onTap,
    this.trailingIcon = AssetIcons.navigateNext,
    this.trailingIconColor,
  });

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: InkWell(
      onTap: onTap,
      child: Ink(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    title,
                    style: context.textTheme.bodyLarge,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              CustomIcon.medium(
                icon: trailingIcon,
                color: trailingIconColor ?? context.colors.neutralDark,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
