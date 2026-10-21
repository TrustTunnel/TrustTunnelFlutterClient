import 'package:flutter/material.dart';
import 'package:trusttunnel/common/assets/asset_icons.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/common/router/app_routes.dart';
import 'package:trusttunnel/data/model/server.dart';
import 'package:trusttunnel/data/model/server_data.dart';
import 'package:trusttunnel/feature/server/server_details/widgets/server_details_popup.dart';
import 'package:trusttunnel/feature/server/server_sharing/widgets/scope/server_sharing_scope.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope_aspect.dart';
import 'package:trusttunnel/feature/server/servers/widget/servers_card.dart';
import 'package:trusttunnel/feature/server/servers/widget/servers_empty_placeholder.dart';
import 'package:trusttunnel/widgets/buttons/custom_floating_action_button.dart';
import 'package:trusttunnel/widgets/common/scaffold_messenger_provider.dart';
import 'package:trusttunnel/widgets/custom_app_bar.dart';
import 'package:trusttunnel/widgets/scaffold_wrapper.dart';

class ServersScreenView extends StatefulWidget {
  final ServerData? deepLinkData;

  const ServersScreenView({
    super.key,
    this.deepLinkData,
  });

  @override
  State<ServersScreenView> createState() => _ServersScreenViewState();
}

class _ServersScreenViewState extends State<ServersScreenView> {
  late List<Server> _servers;
  late final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey;

  @override
  void initState() {
    super.initState();
    final initialController = ServersScope.controllerOf(context, listen: false);
    _servers = initialController.servers;
    _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

    if (widget.deepLinkData != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        _pushServerDetailsScreen(
          context,
          preloadedData: widget.deepLinkData,
        );
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _servers = ServersScope.controllerOf(
      context,
      aspect: ServersScopeAspect.servers,
    ).servers;
  }

  @override
  Widget build(BuildContext context) => ScaffoldWrapper(
    child: ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Builder(
        builder: (context) => Scaffold(
          appBar: CustomAppBar(
            title: context.ln.servers,
          ),
          body: _servers.isEmpty
              ? const ServersEmptyPlaceholder()
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: _servers.length,
                  findChildIndexCallback: (key) {
                    final index = _servers.indexWhere((server) => ValueKey(server.id) == key);

                    return index < 0 ? null : index;
                  },
                  itemBuilder: (_, index) {
                    final server = _servers[index];

                    return Column(
                      key: ValueKey(server.id),
                      children: [
                        ServersCard(
                          server: server,
                          onEdit: () => _pushServerDetailsScreen(context, serverId: server.id),
                          onShare: (origin) => _shareServer(context, server, origin),
                          onCopyLink: () => _copyServerLink(context, server),
                          onDuplicate: () => _duplicateServer(context, server),
                        ),

                        if (index != _servers.length - 1) const Divider(),
                      ],
                    );
                  },
                ),
          floatingActionButton: _servers.isEmpty
              ? null
              : Builder(
                  builder: (context) => CustomFloatingActionButton.extended(
                    icon: AssetIcons.add,
                    onPressed: () => _pushServerDetailsScreen(context),
                    label: context.ln.addServer,
                  ),
                ),
        ),
      ),
    ),
  );

  void _pushServerDetailsScreen(
    BuildContext context, {
    ServerData? preloadedData,
    String? serverId,
  }) async {
    final controller = ServersScope.controllerOf(context, listen: false);
    final Widget serverDetailsScreen;

    if (preloadedData != null) {
      serverDetailsScreen = ServerDetailsPopUp.preloaded(
        preloadedData: preloadedData,
      );
    } else {
      serverDetailsScreen = ServerDetailsPopUp(serverId: serverId);
    }

    await context.push(
      ScaffoldMessengerProvider(
        value: _scaffoldMessengerKey.currentState ?? ScaffoldMessenger.of(context),
        child: serverDetailsScreen,
      ),
      route: AppRoutes.serverDetails,
    );

    if (!mounted || !context.mounted) {
      return;
    }

    controller.fetchServers();
  }

  void _copyServerLink(BuildContext context, Server server) =>
      ServerSharingScope.controllerOf(context, listen: false).copyLink(
        server: server.serverData,
        onCopied: () {
          if (!mounted || !context.mounted) {
            return;
          }

          context.showInfoSnackBar(message: context.ln.serverLinkCopied);
        },
        onError: () => _showOperationError(context),
      );

  void _shareServer(
    BuildContext context,
    Server server,
    Rect origin,
  ) => ServerSharingScope.controllerOf(context, listen: false).share(
    server: server.serverData,
    sharePositionOrigin: origin,
    onError: () => _showOperationError(context),
  );

  void _duplicateServer(BuildContext context, Server server) =>
      ServersScope.controllerOf(context, listen: false).duplicateServer(
        serverId: server.id,
        copyName: context.ln.serverCopyName,
        numberedName: context.ln.serverCopyNumberedName,
        onDuplicated: (duplicate) {
          if (!mounted || !context.mounted) {
            return;
          }

          context.showInfoSnackBar(
            message: context.ln.serverDuplicated,
            trailingActions: [
              TextButton(
                onPressed: () {
                  if (!mounted || !context.mounted) {
                    return;
                  }

                  context.closeCurrentSnackBar();
                  _pushServerDetailsScreen(context, serverId: duplicate.id);
                },
                child: Text(
                  context.ln.edit,
                  style: context.textTheme.labelLarge?.copyWith(
                    color: context.colors.specialStaticWhite,
                  ),
                ),
              ),
            ],
          );
        },
        onError: () => _showOperationError(context),
      );

  void _showOperationError(BuildContext context) {
    if (!mounted || !context.mounted) {
      return;
    }

    context.showInfoSnackBar(message: context.ln.somethingWentWrongSnackbar);
  }
}
