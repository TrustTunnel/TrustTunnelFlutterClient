import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:trusttunnel/common/error/model/enum/presentation_field_name.dart';
import 'package:trusttunnel/common/error/model/presentation_field.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/extensions/theme_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/feature/routing/routing/widgets/scope/routing_scope.dart';
import 'package:trusttunnel/feature/routing/routing/widgets/scope/routing_scope_aspect.dart';
import 'package:trusttunnel/widgets/custom_alert_dialog.dart';
import 'package:trusttunnel/widgets/inputs/custom_text_field.dart';

class RoutingEditNameDialog extends StatefulWidget {
  final String currentRoutingName;
  final int id;

  const RoutingEditNameDialog({
    super.key,
    required this.currentRoutingName,
    required this.id,
  });

  @override
  State<RoutingEditNameDialog> createState() => _RoutingEditNameDialogState();
}

class _RoutingEditNameDialogState extends State<RoutingEditNameDialog> {
  late String _routingName = widget.currentRoutingName;
  late List<PresentationField> _fieldErrors;

  @override
  void initState() {
    super.initState();
    _fieldErrors = RoutingScope.controllerOf(context, listen: false).fieldErrors;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fieldErrors = RoutingScope.controllerOf(
      context,
      aspect: RoutingScopeAspect.name,
    ).fieldErrors;
  }

  @override
  Widget build(BuildContext context) {
    final error = _fieldErrors.firstWhereOrNull(
      (element) => element.fieldName == PresentationFieldName.profileName,
    );

    return CustomAlertDialog(
      title: context.ln.editProfile,
      scrollable: true,
      content: Padding(
        padding: const EdgeInsets.only(top: 24),
        child: CustomTextField(
          label: context.ln.routingProfile,
          value: _routingName,
          error: error?.toLocalizedString(context),
          onChanged: (name) => _onRoutingNameChanged(name, error != null),
        ),
      ),
      actionsBuilder: (spacing) => [
        TextButton(
          onPressed: context.pop,
          child: Text(context.ln.cancel),
        ),
        Theme(
          data: context.theme.copyWith(
            textButtonTheme: context.theme.extension<CustomTextButtonTheme>()!.success,
          ),
          child: TextButton(
            onPressed: error != null ? null : () => _onSavePressed(_routingName),
            child: Text(context.ln.save),
          ),
        ),
      ],
    );
  }

  void _onRoutingNameChanged(String? name, bool hasErrors) {
    if (name == null || name == _routingName) return;
    _routingName = name;
    if (hasErrors) {
      RoutingScope.controllerOf(context, listen: false).pickProfileToChangeName();
    }
  }

  void _onSavePressed(
    String name,
  ) => RoutingScope.controllerOf(context, listen: false).changeName(
    id: widget.id,
    name: name,
    onSaved: () {
      if (!mounted) {
        return;
      }

      if (Navigator.of(context).canPop()) {
        context.pop();
      }

      context.showInfoSnackBar(message: context.ln.changesSavedSnackbar);
    },
  );
}
