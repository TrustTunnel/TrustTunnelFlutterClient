import 'package:flutter/material.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/extensions/locale_enum_extension.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/data/model/routing_mode.dart';
import 'package:trusttunnel/feature/routing/routing/widgets/scope/routing_scope.dart';
import 'package:trusttunnel/feature/routing/routing_details/widgets/routing_details_form.dart';
import 'package:trusttunnel/feature/routing/routing_details/widgets/routing_details_screen_app_bar_action.dart';
import 'package:trusttunnel/feature/routing/routing_details/widgets/routing_details_submit_button_section.dart';
import 'package:trusttunnel/feature/routing/routing_details/widgets/scope/routing_details_aspect.dart';
import 'package:trusttunnel/feature/routing/routing_details/widgets/scope/routing_details_scope.dart';
import 'package:trusttunnel/widgets/common/scaffold_messenger_provider.dart';
import 'package:trusttunnel/widgets/custom_app_bar.dart';
import 'package:trusttunnel/widgets/discard_changes_dialog.dart';
import 'package:trusttunnel/widgets/scaffold_wrapper.dart';

class RoutingDetailsScreenView extends StatefulWidget {
  const RoutingDetailsScreenView({super.key});

  @override
  State<RoutingDetailsScreenView> createState() => _RoutingDetailsScreenViewState();
}

class _RoutingDetailsScreenViewState extends State<RoutingDetailsScreenView> {
  late bool _hasChanges;
  late bool _hasErrors;
  late bool _isEditing;
  late bool _loading;
  late String _name;
  late RoutingMode _mode;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newData = RoutingDetailsScope.controllerOf(context, aspect: RoutingDetailsScopeAspect.data);

    _hasErrors = newData.hasInvalidRules;
    _hasChanges = newData.hasChanges;
    _name = newData.name;
    _isEditing = newData.editing;
    _loading = newData.loading;
    _mode = newData.data.defaultMode;

    _loading = RoutingDetailsScope.controllerOf(context, aspect: RoutingDetailsScopeAspect.loading).loading;
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_hasChanges,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) {
        _showNotSavedChangesWarning(context);
      }
    },
    child: ScaffoldWrapper(
      child: DefaultTabController(
        length: RoutingMode.values.length,
        child: ScaffoldMessenger(
          child: Scaffold(
            appBar: CustomAppBar(
              leadingIconType: AppBarLeadingIconType.back,
              centerTitle: true,
              onBackPressed: () => Navigator.of(context).maybePop(),
              title: _name,
              actions: [
                RoutingDetailsScreenAppBarAction(
                  profileName: _name,
                  pickedRoutingMode: _mode,
                  onDefaultModePicked: (context, mode) => _onDefaultModePicked(context, mode),
                  onClearRulesPressed: (context) => _onClearRulesPressed(context),
                ),
              ],
              bottomHeight: context.isMobileBreakpoint ? 48 : 0,
              bottomPadding: EdgeInsets.zero,
              bottom: context.isMobileBreakpoint
                  ? TabBar(
                      tabs: [
                        ...RoutingMode.values.map(
                          (item) => Text(
                            item.localized(context),
                          ),
                        ),
                      ],
                    )
                  : null,
            ),
            body: _loading
                ? const SizedBox.shrink()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Expanded(
                        child: RoutingDetailsForm(),
                      ),
                      RoutingDetailsSubmitButtonSection(
                        editing: _isEditing,
                        onPressed: !_hasErrors && _hasChanges ? () => _onSubmitPressed(context) : null,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    ),
  );

  void _onDefaultModePicked(BuildContext context, RoutingMode mode) {
    final routingDetailsController = RoutingDetailsScope.controllerOf(context, listen: false);
    routingDetailsController.changeDefaultRoutingMode(
      mode,
      () => _onDefaultModeChanged(
        context,
        mode,
      ),
    );
  }

  void _onDefaultModeChanged(
    BuildContext context,
    RoutingMode mode,
  ) {
    RoutingScope.controllerOf(context, listen: false).fetchProfiles();

    if (!context.mounted) {
      return;
    }
    context.showInfoSnackBar(message: context.ln.changesSavedSnackbar);
  }

  void _onClearRulesPressed(BuildContext context) =>
      RoutingDetailsScope.controllerOf(context, listen: false).clearRules(
        () => _onClearedRules(context),
      );

  void _onClearedRules(BuildContext context) {
    RoutingScope.controllerOf(context, listen: false).fetchProfiles();

    context.showInfoSnackBar(message: context.ln.allRulesDeleted);
  }

  void _onSubmitPressed(BuildContext context) => RoutingDetailsScope.controllerOf(context, listen: false).submit(
    () => _onSubmitted(context),
  );

  void _onSubmitted(BuildContext context) {
    RoutingScope.controllerOf(context, listen: false).fetchProfiles();

    if (!context.mounted) {
      return;
    }

    if (Navigator.of(context).canPop()) {
      context.pop();
    }

    if (!_isEditing) {
      context.showInfoSnackBar(message: context.ln.profileCreatedSnackbar(_name));

      return;
    }

    context.showInfoSnackBar(message: context.ln.changesSavedSnackbar);
  }

  void _showNotSavedChangesWarning(BuildContext context) {
    final parentScaffoldMessenger = ScaffoldMessenger.maybeOf(context);

    showDialog(
      context: context,
      builder: (innerContext) => ScaffoldMessengerProvider(
        value: parentScaffoldMessenger ?? ScaffoldMessenger.of(innerContext),
        child: DiscardChangesDialog(
          onDiscardPressed: context.pop,
        ),
      ),
    );
  }
}
