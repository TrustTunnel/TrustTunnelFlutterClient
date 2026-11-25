import 'package:flutter/material.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/extensions/locale_enum_extension.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/data/model/routing_mode.dart';
import 'package:trusttunnel/feature/routing/routing/widgets/scope/routing_scope.dart';
import 'package:trusttunnel/feature/routing/routing/widgets/scope/routing_scope_controller.dart';
import 'package:trusttunnel/feature/routing/routing_details/widgets/routing_details_form.dart';
import 'package:trusttunnel/feature/routing/routing_details/widgets/routing_details_screen_app_bar_action.dart';
import 'package:trusttunnel/feature/routing/routing_details/widgets/routing_details_submit_button_section.dart';
import 'package:trusttunnel/feature/routing/routing_details/widgets/scope/routing_details_aspect.dart';
import 'package:trusttunnel/feature/routing/routing_details/widgets/scope/routing_details_controller.dart';
import 'package:trusttunnel/feature/routing/routing_details/widgets/scope/routing_details_scope.dart';
import 'package:trusttunnel/widgets/custom_app_bar.dart';
import 'package:trusttunnel/widgets/discard_changes_dialog.dart';
import 'package:trusttunnel/widgets/scaffold_wrapper.dart';

class RoutingDetailsScreenView extends StatefulWidget {
  const RoutingDetailsScreenView({super.key});

  @override
  State<RoutingDetailsScreenView> createState() => _RoutingDetailsScreenViewState();
}

class _RoutingDetailsScreenViewState extends State<RoutingDetailsScreenView> {
  late RoutingScopeController _routingController;
  late RoutingDetailsScopeController _detailsController;
  late bool _hasChanges;
  late bool _hasErrors;
  late bool _isEditing;
  late bool _loading;
  late bool _updatingPartOfProfile;
  late String _name;
  late RoutingMode _mode;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routingController = RoutingScope.controllerOf(context, listen: false);
    _detailsController = RoutingDetailsScope.controllerOf(context, aspect: RoutingDetailsScopeAspect.data);

    _hasErrors = _detailsController.hasInvalidRules;
    _hasChanges = _detailsController.hasChanges;
    _name = _detailsController.name;
    _isEditing = _detailsController.editing;
    _mode = _detailsController.data.defaultMode;

    final loadingUpdate = RoutingDetailsScope.controllerOf(context, aspect: RoutingDetailsScopeAspect.loading);
    _loading = loadingUpdate.loading;
    _updatingPartOfProfile = loadingUpdate.updatingPartOfProfile;
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_hasChanges || (_loading && !_updatingPartOfProfile),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) {
        showDiscardChangesDialog(context);
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
                  enabled: !_loading,
                  onDefaultModePicked: _onDefaultModePicked,
                  onClearRulesPressed: _onClearRulesPressed,
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
                        onPressed: !_hasErrors && _hasChanges ? _onSubmitPressed : null,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    ),
  );

  void _onDefaultModePicked(BuildContext context, RoutingMode mode) {
    if (!context.mounted || _loading) {
      return;
    }

    final fetchProfiles = _routingController.fetchProfiles;
    _detailsController.changeDefaultRoutingMode(
      mode: mode,
      onChanged: () {
        fetchProfiles();

        if (context.mounted) {
          context.showInfoSnackBar(message: context.ln.changesSavedSnackbar);
        }
      },
    );
  }

  void _onClearRulesPressed(BuildContext context) {
    if (!context.mounted || _loading) {
      return;
    }

    final fetchProfiles = _routingController.fetchProfiles;
    _detailsController.clearRules(() {
      fetchProfiles();

      if (context.mounted) {
        context.showInfoSnackBar(message: context.ln.allRulesDeleted);
      }
    });
  }

  void _onSubmitPressed() {
    final fetchProfiles = _routingController.fetchProfiles;
    final formRoute = ModalRoute.of(context);

    _detailsController.submit(() {
      fetchProfiles();

      if (mounted && formRoute?.isCurrent == true) {
        _onSubmitted(context);
      }
    });
  }

  void _onSubmitted(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      context.pop();
    }

    if (!_isEditing) {
      context.showInfoSnackBar(message: context.ln.profileCreatedSnackbar(_name));

      return;
    }

    context.showInfoSnackBar(message: context.ln.changesSavedSnackbar);
  }
}
