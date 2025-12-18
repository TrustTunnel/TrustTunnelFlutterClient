import 'package:flutter/material.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/extensions/theme_extensions.dart';
import 'package:trusttunnel/common/localization/extensions/locale_enum_extension.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/data/model/routing_mode.dart';
import 'package:trusttunnel/widgets/custom_alert_dialog.dart';
import 'package:trusttunnel/widgets/menu/custom_dropdown_menu.dart';

class RoutingDetailsChangeRoutingDialog extends StatefulWidget {
  final ValueChanged<RoutingMode> onSavePressed;
  final RoutingMode currentRoutingMode;

  const RoutingDetailsChangeRoutingDialog({
    super.key,
    required this.onSavePressed,
    required this.currentRoutingMode,
  });

  @override
  State<RoutingDetailsChangeRoutingDialog> createState() => _RoutingDetailsChangeRoutingDialogState();
}

class _RoutingDetailsChangeRoutingDialogState extends State<RoutingDetailsChangeRoutingDialog> {
  late RoutingMode _selectedRoutingMode = widget.currentRoutingMode;

  @override
  Widget build(BuildContext context) => CustomAlertDialog(
    title: context.ln.changeDefaultRoutingMode,
    scrollable: true,
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.ln.changeDefaultRoutingModeDialogDescription),
        const SizedBox(height: 40),
        CustomDropdownMenu<RoutingMode>.expanded(
          value: _selectedRoutingMode,
          values: [
            RoutingMode.vpn,
            RoutingMode.bypass,
          ],
          toText: (value) => value.localized(context),
          labelText: context.ln.defaultProfile,
          onChanged: _onRoutingChanged,
        ),
      ],
    ),
    actionsBuilder: (spacing) => [
      TextButton(
        onPressed: () => context.pop(),
        child: Text(context.ln.cancel),
      ),
      Theme(
        data: context.theme.copyWith(
          textButtonTheme: context.theme.extension<CustomTextButtonTheme>()!.success,
        ),
        child: TextButton(
          onPressed: _selectedRoutingMode == widget.currentRoutingMode
              ? null
              : () {
                  context.pop();
                  widget.onSavePressed(_selectedRoutingMode);
                },
          child: Text(context.ln.save),
        ),
      ),
    ],
  );

  void _onRoutingChanged(RoutingMode? mode) {
    if (mode == null || mode == _selectedRoutingMode) return;
    setState(() {
      _selectedRoutingMode = mode;
    });
  }
}
