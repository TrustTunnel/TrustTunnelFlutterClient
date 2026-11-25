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
  late bool _loading;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = ExcludedRoutesScope.controllerOf(
      context,
      aspect: ExcludedRoutesAspect.data,
    );
    _hasChanges = _controller.hasChanges;
    _loading = ExcludedRoutesScope.controllerOf(context, aspect: ExcludedRoutesAspect.loading).loading;
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_hasChanges || _loading,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) {
        showDiscardChangesDialog(context);
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
            ExcludedRoutesButtonSection(onSavePressed: _loading ? null : _saveExcludedRoutes),
          ],
        ),
      ),
    ),
  );

  void _saveExcludedRoutes() {
    final formRoute = ModalRoute.of(context);

    _controller.submit(() {
      if (mounted && formRoute?.isCurrent == true && Navigator.canPop(context)) {
        context.pop();
      }
    });
  }
}
