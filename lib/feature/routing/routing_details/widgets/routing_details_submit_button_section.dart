import 'package:flutter/material.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';

class RoutingDetailsSubmitButtonSection extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool editing;

  const RoutingDetailsSubmitButtonSection({
    super.key,
    this.onPressed,
    required this.editing,
  });

  @override
  Widget build(BuildContext context) {
    final button = FilledButton(
      onPressed: onPressed,
      child: Text(
        editing ? context.ln.save : context.ln.add,
      ),
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: context.isMobileBreakpoint
          ? button
          : Align(
              alignment: Alignment.centerRight,
              child: button,
            ),
    );
  }
}
