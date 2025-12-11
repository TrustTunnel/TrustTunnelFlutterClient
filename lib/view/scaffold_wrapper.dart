import 'package:flutter/material.dart';
import 'package:vpn/common/extensions/context_extensions.dart';

class ScaffoldWrapper extends StatelessWidget {
  final Widget child;

  const ScaffoldWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.colors.backgroundSystem,
    child: Padding(
      padding: EdgeInsets.all(context.isMobileBreakpoint ? 0 : 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(context.isMobileBreakpoint ? 0 : 16),
        child: ColoredBox(
          color: context.colors.background,
          child: child,
        ),
      ),
    ),
  );
}
