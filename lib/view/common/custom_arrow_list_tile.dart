import 'package:flutter/material.dart';
import 'package:vpn/common/assets/asset_icons.dart';
import 'package:vpn/common/extensions/context_extensions.dart';
import 'package:vpn/view/custom_icon.dart';

class CustomArrowListTile extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const CustomArrowListTile({
    super.key,
    required this.title,
    required this.onTap,
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
                icon: AssetIcons.navigateNext,
                color: context.colors.neutralDark,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
