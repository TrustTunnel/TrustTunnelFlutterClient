import 'package:flutter/material.dart';
import 'package:vpn/common/extensions/context_extensions.dart';

class ProgressWrapper extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final Color? color;

  const ProgressWrapper({
    super.key,
    required this.isLoading,
    required this.child,
    this.color,
  });

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.passthrough,
    children: [
      child,
      if (isLoading)
        Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: ColoredBox(
              color: color ?? context.colors.background,
              child: LinearProgressIndicator(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
    ],
  );
}
