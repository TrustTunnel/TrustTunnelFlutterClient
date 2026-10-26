import 'package:flutter/material.dart';
import 'package:trusttunnel/data/model/server_data.dart';
import 'package:trusttunnel/feature/server/server_sharing/widgets/scope/server_sharing_scope.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope.dart';
import 'package:trusttunnel/feature/server/servers/widget/servers_screen_view.dart';

class ServersScreen extends StatefulWidget {
  final ServerData? deepLinkData;

  const ServersScreen({
    super.key,
    this.deepLinkData,
  });

  @override
  State<ServersScreen> createState() => _ServersScreenState();
}

class _ServersScreenState extends State<ServersScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      ServersScope.controllerOf(context, listen: false).fetchServers();
    });
  }

  @override
  Widget build(BuildContext context) => ServerSharingScope(
    child: ServersScreenView(
      deepLinkData: widget.deepLinkData,
    ),
  );
}
