import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/extensions/locale_enum_extension.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/data/model/routing_mode.dart';
import 'package:trusttunnel/data/model/routing_profile.dart';
import 'package:trusttunnel/data/model/vpn_state.dart';
import 'package:trusttunnel/feature/routing/routing/widgets/scope/routing_scope.dart';
import 'package:trusttunnel/feature/routing/routing/widgets/scope/routing_scope_controller.dart';
import 'package:trusttunnel/feature/routing/routing_details/widgets/routing_details_discard_changes_dialog.dart';
import 'package:trusttunnel/feature/routing/routing_details/widgets/routing_details_form.dart';
import 'package:trusttunnel/feature/routing/routing_details/widgets/routing_details_screen_app_bar_action.dart';
import 'package:trusttunnel/feature/routing/routing_details/widgets/routing_details_submit_button_section.dart';
import 'package:trusttunnel/feature/routing/routing_details/widgets/scope/routing_details_aspect.dart';
import 'package:trusttunnel/feature/routing/routing_details/widgets/scope/routing_details_scope.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope_controller.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/scope/excluded_routes_scope.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/scope/excluded_routes_scope_controller.dart';
import 'package:trusttunnel/feature/vpn/models/vpn_controller.dart';
import 'package:trusttunnel/feature/vpn/widgets/vpn_scope.dart';
import 'package:trusttunnel/widgets/custom_app_bar.dart';
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
  void initState() {
    super.initState();
    final initialData = RoutingDetailsScope.controllerOf(context, listen: false);
    _hasErrors = initialData.hasInvalidRules;
    _hasChanges = initialData.hasChanges;
    _name = initialData.name;
    _isEditing = initialData.editing;
    _loading = initialData.loading;
    _mode = initialData.data.defaultMode;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newData = RoutingDetailsScope.controllerOf(context, aspect: RoutingDetailsScopeAspect.data);

    _hasErrors = newData.hasInvalidRules;
    _hasChanges = newData.hasChanges;
    _name = newData.name;
    _mode = newData.data.defaultMode;

    _loading = RoutingDetailsScope.controllerOf(context, aspect: RoutingDetailsScopeAspect.loading).loading;
  }

  @override
  Widget build(BuildContext context) => ScaffoldWrapper(
    child: DefaultTabController(
      length: RoutingMode.values.length,
      child: ScaffoldMessenger(
        child: Scaffold(
          appBar: CustomAppBar(
            leadingIconType: AppBarLeadingIconType.back,
            centerTitle: true,
            onBackPressed: _hasChanges ? () => _showNotSavedChangesWarning(context) : null,
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
  );

  void onUpdated(
    VpnController controller,
    ServersScopeController serverController,
    RoutingScopeController routingProfileController,
    RoutingProfile profile,
    ExcludedRoutesScopeController excludedRoutesController,
  ) {
    routingProfileController.fetchProfiles();

    final selectedServer = serverController.servers.firstWhereOrNull(
      (server) => server.id == serverController.selectedServer?.id,
    );

    if (selectedServer != null) {
      bool picked = selectedServer.routingProfile.id == profile.id;
      bool running = controller.state != VpnState.disconnected;

      if (picked && running) {
        controller.start(
          server: selectedServer,
          routingProfile: profile,
          excludedRoutes: excludedRoutesController.excludedRoutes,
        );
      }
    }
  }

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
    if (!context.mounted) {
      return;
    }

    context.showInfoSnackBar(message: context.ln.changesSavedSnackbar);

    final state = RoutingDetailsScope.controllerOf(context, listen: false);

    final routingProfile = RoutingProfile(
      id: state.id ?? -1,
      name: _name,
      defaultMode: mode,
      bypassRules: state.initialData.bypassRules,
      vpnRules: state.initialData.vpnRules,
    );

    onUpdated(
      VpnScope.vpnControllerOf(context, listen: false),
      ServersScope.controllerOf(context, listen: false),
      RoutingScope.controllerOf(context, listen: false),
      routingProfile,
      ExcludedRoutesScope.controllerOf(context, listen: false),
    );
  }

  void _onClearRulesPressed(BuildContext context) =>
      RoutingDetailsScope.controllerOf(context, listen: false).clearRules(
        () => _onClearedRules(context),
      );

  void _onClearedRules(BuildContext context) {
    final state = RoutingDetailsScope.controllerOf(context, listen: false);

    final routingProfile = RoutingProfile(
      id: state.id ?? -1,
      name: _name,
      defaultMode: state.initialData.defaultMode,
      bypassRules: [],
      vpnRules: [],
    );

    onUpdated(
      VpnScope.vpnControllerOf(context, listen: false),
      ServersScope.controllerOf(context, listen: false),
      RoutingScope.controllerOf(context, listen: false),
      routingProfile,
      ExcludedRoutesScope.controllerOf(context, listen: false),
    );

    context.showInfoSnackBar(message: context.ln.allRulesDeleted);
  }

  void _onSubmitPressed(BuildContext context) => RoutingDetailsScope.controllerOf(context, listen: false).submit(
    () => _onSubmitted(context),
  );

  void _onSubmitted(BuildContext context) {
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
    final currentProfileState = RoutingDetailsScope.controllerOf(context, listen: false);

    final routingProfile = RoutingProfile(
      id: currentProfileState.id ?? -1,
      name: _name,
      defaultMode: currentProfileState.data.defaultMode,
      bypassRules: currentProfileState.data.bypassRules,
      vpnRules: currentProfileState.data.vpnRules,
    );

    onUpdated(
      VpnScope.vpnControllerOf(context, listen: false),
      ServersScope.controllerOf(context, listen: false),
      RoutingScope.controllerOf(context, listen: false),
      routingProfile,
      ExcludedRoutesScope.controllerOf(context, listen: false),
    );
  }

  void _showNotSavedChangesWarning(BuildContext context) => showDialog(
    context: context,
    builder: (_) => RoutingDetailsDiscardChangesDialog(
      onDiscardPressed: () => context.pop(),
    ),
  );
}
