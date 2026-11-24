import 'dart:async';

import 'package:flutter/material.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/excluded_routes_button_section.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/excluded_routes_form.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/scope/excluded_routes_aspect.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/scope/excluded_routes_scope.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/scope/excluded_routes_scope_controller.dart';
import 'package:trusttunnel/widgets/custom_app_bar.dart';
import 'package:trusttunnel/widgets/discard_changes_dialog.dart';
import 'package:trusttunnel/widgets/scaffold_wrapper.dart';

class ExcludedRoutesScreenView extends StatefulWidget {
  const ExcludedRoutesScreenView({
    super.key,
  });

  @override
  State<ExcludedRoutesScreenView> createState() => _ExcludedRoutesScreenViewState();
}

class _ExcludedRoutesScreenViewState extends State<ExcludedRoutesScreenView> {
  late ExcludedRoutesScopeController _controller;
  late bool _hasChanges;
  bool _isFormSaving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = ExcludedRoutesScope.controllerOf(
      context,
      aspect: ExcludedRoutesAspect.data,
    );
    _hasChanges = _controller.hasChanges;
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_isFormSaving && !_hasChanges,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && !_isFormSaving) {
        unawaited(DiscardChangesDialog.show(context));
      }
    },
    child: ScaffoldWrapper(
      child: Scaffold(
        appBar: CustomAppBar(
          title: context.ln.excludedRoutes,
        ),
        body: Column(
          children: [
            const Expanded(
              child: ExcludedRoutesForm(),
            ),
            ExcludedRoutesButtonSection(onSavePressed: _isFormSaving ? null : _saveExcludedRoutes),
          ],
        ),
      ),
    ),
  );

  void _saveExcludedRoutes() {
    if (_isFormSaving) {
      return;
    }

    final formRoute = ModalRoute.of(context);
    setState(() => _isFormSaving = true);

    _controller.submit(
      onSaved: () {
        if (mounted && formRoute?.isCurrent == true && Navigator.canPop(context)) {
          context.pop();
        }
      },
      onFinished: () {
        if (mounted) {
          setState(() => _isFormSaving = false);
        }
      },
    );
  }
}
