import 'package:flutter/material.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/widgets/buttons/custom_icon_button.dart';
import 'package:trusttunnel/widgets/custom_icon.dart';

const _toolbarHeight = 64.0;

enum AppBarLeadingIconType {
  back,
  close,
  drawer,
}

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onBackPressed;
  final List<Widget>? actions;
  final bool showDivider;
  final Widget? bottom;
  final double bottomHeight;
  final Alignment bottomAlign;
  final EdgeInsetsGeometry bottomPadding;
  final bool? centerTitle;
  final AppBarLeadingIconType? leadingIconType;

  const CustomAppBar({
    super.key,
    required this.title,
    this.showDivider = false,
    this.leadingIconType,
    this.onBackPressed,
    this.actions,
    this.bottom,
    this.bottomHeight = 0.0,
    this.centerTitle,
    this.bottomAlign = Alignment.bottomCenter,
    this.bottomPadding = const EdgeInsets.symmetric(horizontal: 24),
  });

  @override
  Widget build(BuildContext context) {
    final showBackButton = leadingIconType != null;
    final backButton = showBackButton ? _getBackButtonByType(context, leadingIconType!) : null;
    final body = AppBar(
      centerTitle: centerTitle ?? !showBackButton,
      title: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Text(title),
      ),
      backgroundColor: context.colors.background,
      bottom: bottom != null
          ? PreferredSize(
              preferredSize: Size.fromHeight(bottomHeight),
              child: SizedBox(
                height: bottomHeight,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: centerTitle ?? true ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: bottomAlign,
                      child: Padding(
                        padding: bottomPadding,
                        child: bottom!,
                      ),
                    ),
                    if (showDivider) const Divider(),
                  ],
                ),
              ),
            )
          : null,
      leading: showBackButton
          ? CustomIconButton.custom(
              onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
              iconWidget: backButton ?? CustomIcon.medium(icon: Icons.close),
            )
          : null,
      actions: actions,
    );

    return (context.isMobileBreakpoint || !showDivider)
        ? body
        : Stack(
            children: [
              body,
              const Align(
                alignment: Alignment.bottomCenter,
                child: Divider(),
              ),
            ],
          );
  }

  @override
  Size get preferredSize {
    final double dividerHeight = showDivider ? 1 : 0;
    final toolbarHeight = bottom == null ? _toolbarHeight : _toolbarHeight + bottomHeight + dividerHeight;

    return Size.fromHeight(toolbarHeight);
  }

  Widget? _getBackButtonByType(BuildContext context, AppBarLeadingIconType leadingIconType) {
    final actionTheme = context.theme.actionIconTheme;
    switch (leadingIconType) {
      case AppBarLeadingIconType.back:
        return actionTheme?.backButtonIconBuilder?.call(context);
      case AppBarLeadingIconType.close:
        return actionTheme?.closeButtonIconBuilder?.call(context);
      case AppBarLeadingIconType.drawer:
        return actionTheme?.drawerButtonIconBuilder?.call(context);
    }
  }
}
