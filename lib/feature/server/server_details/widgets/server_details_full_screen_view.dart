import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:trusttunnel/common/assets/asset_icons.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/data/model/server.dart';
import 'package:trusttunnel/data/model/vpn_state.dart';
import 'package:trusttunnel/feature/routing/routing/widgets/scope/routing_scope.dart';
import 'package:trusttunnel/feature/routing/routing/widgets/scope/routing_scope_controller.dart';
import 'package:trusttunnel/feature/server/server_details/model/server_details_data.dart';
import 'package:trusttunnel/feature/server/server_details/widgets/scope/server_details_scope.dart';
import 'package:trusttunnel/feature/server/server_details/widgets/scope/server_details_scope_aspect.dart';
import 'package:trusttunnel/feature/server/server_details/widgets/server_details_delete_dialog.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope_controller.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/scope/excluded_routes_scope.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/scope/excluded_routes_scope_controller.dart';
import 'package:trusttunnel/feature/vpn/models/vpn_controller.dart';
import 'package:trusttunnel/feature/vpn/widgets/vpn_scope.dart';
import 'package:trusttunnel/widgets/buttons/custom_icon_button.dart';
import 'package:trusttunnel/widgets/common/scaffold_messenger_provider.dart';
import 'package:trusttunnel/widgets/custom_app_bar.dart';

class ServerDetailsFullScreenView extends StatefulWidget {
  final Widget body;
  final ValueChanged<bool> onDiscardChanges;

  const ServerDetailsFullScreenView({
    super.key,
    required this.body,
    required this.onDiscardChanges,
  });

  @override
  State<ServerDetailsFullScreenView> createState() => _ServerDetailsFullScreenViewState();
}

class _ServerDetailsFullScreenViewState extends State<ServerDetailsFullScreenView> {
  late bool _hasChanges;
  late final bool _editing;
  late ServerDetailsData _data;
  late bool loading;
  late int? _id;

  @override
  void initState() {
    super.initState();
    final initialDataScope = ServerDetailsScope.controllerOf(context, listen: false);
    _id = initialDataScope.id;
    _hasChanges = initialDataScope.hasChanges;
    _editing = initialDataScope.editing;
    _data = initialDataScope.data;
    loading = initialDataScope.loading;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final dataUpdate = ServerDetailsScope.controllerOf(
      context,
      aspect: ServerDetailsScopeAspect.data,
    );

    _hasChanges = dataUpdate.hasChanges;
    _data = dataUpdate.data;

    final loadingUpdate = ServerDetailsScope.controllerOf(
      context,
      aspect: ServerDetailsScopeAspect.loading,
    );

    loading = loadingUpdate.loading;
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Scaffold(
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: CustomAppBar(
              actions: [
                if (_editing)
                  CustomIconButton.square(
                    icon: AssetIcons.delete,
                    color: context.colors.error,
                    size: 24,
                    onPressed: () => _onDelete(context),
                  ),
              ],
              leadingIconType: AppBarLeadingIconType.back,
              centerTitle: true,
              onBackPressed: () => widget.onDiscardChanges.call(_hasChanges),
              title: _editing ? context.ln.editServer : context.ln.addServer,
            ),
          ),
          SliverToBoxAdapter(
            child: loading ? const SizedBox.shrink() : widget.body,
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            fillOverscroll: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton(
                    onPressed: _hasChanges ? () => _submit(context) : null,
                    child: Text(
                      _editing ? context.ln.save : context.ln.add,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  void _submit(BuildContext context) => ServerDetailsScope.controllerOf(context, listen: false).submit(_onSubmitted);

  void _onDelete(BuildContext context) {
    final parentScaffoldMessenger = ScaffoldMessenger.maybeOf(context);

    showDialog(
      context: context,
      builder: (innerContext) => ScaffoldMessengerProvider(
        value: parentScaffoldMessenger ?? ScaffoldMessenger.of(innerContext),
        child: ServerDetailsDeleteDialog(
          serverName: _data.serverName,
          onDeletePressed: () => ServerDetailsScope.controllerOf(context, listen: false).delete(_onDeleted),
        ),
      ),
    );
  }

  void _onDeleted(String name) {
    if (!mounted) {
      return;
    }

    _onUpdated(
      VpnScope.vpnControllerOf(context),
      ServersScope.controllerOf(context),
      RoutingScope.controllerOf(context),
      ExcludedRoutesScope.controllerOf(context),
      _data,
      deleted: true,
    );

    if (Navigator.of(context).canPop()) {
      context.pop();
    }

    context.showInfoSnackBar(message: context.ln.serverDeletedSnackbar(name));
  }

  void _onSubmitted(String name) {
    final String snackbarText;

    if (!mounted) {
      return;
    }

    if (_editing) {
      snackbarText = context.ln.changesSavedSnackbar;
    } else {
      snackbarText = context.ln.serverCreatedSnackbar(name);
    }

    _onUpdated(
      VpnScope.vpnControllerOf(context),
      ServersScope.controllerOf(context),
      RoutingScope.controllerOf(context),
      ExcludedRoutesScope.controllerOf(context),
      _data,
    );

    if (Navigator.canPop(context)) {
      context.pop();
    }

    context.showInfoSnackBar(message: snackbarText);
  }

  void _onUpdated(
    VpnController controller,
    ServersScopeController serverController,
    RoutingScopeController profileController,
    ExcludedRoutesScopeController excludedRoutesController,
    ServerDetailsData data, {
    bool deleted = false,
  }) {
    serverController.fetchServers();

    final selectedServer = serverController.servers.firstWhereOrNull(
      (server) => serverController.selectedServer?.id == _id,
    );

    final profile = profileController.routingList.firstWhereOrNull(
      (profile) => profile.id == data.routingProfileId,
    );

    if (selectedServer != null && profile != null) {
      bool running = controller.state != VpnState.disconnected;
      final excludedRoutes = excludedRoutesController.excludedRoutes;

      if (running) {
        if (deleted) {
          controller.stop();

          return;
        }

        controller.start(
          server: Server(
            id: selectedServer.id,
            name: data.serverName,
            ipAddress: data.ipAddress,
            domain: data.domain,
            username: data.username,
            password: data.password,
            vpnProtocol: data.protocol,
            dnsServers: data.dnsServers,
            routingProfile: profile,
            selected: selectedServer.selected,
          ),
          routingProfile: profile,
          excludedRoutes: excludedRoutes,
        );
      }
    }
  }
}
