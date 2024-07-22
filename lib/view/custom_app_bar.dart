import 'package:flutter/material.dart';
import 'package:vpn/common/extensions/context_extensions.dart';

const _toolbarHeight = 64.0;

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  final bool showDrawerButton;
  final VoidCallback? onBackPressed;
  final List<Widget>? actions;
  final bool showDivider;
  final Widget? bottom;
  final double bottomHeight;
  final Alignment bottomAlign;
  final EdgeInsetsGeometry bottomPadding;
  final bool? centerTitle;

  const CustomAppBar({
    super.key,
    required this.title,
    this.showBackButton = false,
    this.showDrawerButton = false,
    this.showDivider = false,
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
    final body = AppBar(
      centerTitle: centerTitle ?? !showBackButton,
      surfaceTintColor:
          context.isMobileBreakpoint ? context.colors.gray1 : null,
      title: Text(title),
      backgroundColor: context.colors.background1,
      bottom: bottom != null
          ? PreferredSize(
              preferredSize: Size.fromHeight(bottomHeight),
              child: SizedBox(
                height: bottomHeight,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: centerTitle ?? true
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
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
          ? IconButton(
              onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
              icon: context.theme.actionIconTheme!.backButtonIconBuilder!
                  .call(context),
            )
          : null,
      actions: actions,
    );

    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: (context.isMobileBreakpoint || !showDivider)
            ? body
            : Stack(
                children: [
                  body,
                  const Align(
                    alignment: Alignment.bottomCenter,
                    child: Divider(),
                  ),
                ],
              ));
  }

  @override
  Size get preferredSize {
    final double dividerHeight = showDivider ? 1 : 0;
    final toolbarHeight = bottom == null
        ? _toolbarHeight
        : _toolbarHeight + bottomHeight + dividerHeight;

    return Size.fromHeight(toolbarHeight);
  }
}