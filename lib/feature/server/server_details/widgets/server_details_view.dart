import 'package:flutter/material.dart';
import 'package:trusttunnel/feature/server/server_details/widgets/scope/server_details_scope.dart';
import 'package:trusttunnel/feature/server/server_details/widgets/server_details_form.dart';
import 'package:trusttunnel/feature/server/server_details/widgets/server_details_full_screen_view.dart';

class ServerDetailsView extends StatefulWidget {
  const ServerDetailsView({
    super.key,
  });

  @override
  State<ServerDetailsView> createState() => _ServerDetailsViewState();
}

class _ServerDetailsViewState extends State<ServerDetailsView> {
  @override
  void initState() {
    super.initState();
    ServerDetailsScope.controllerOf(context, listen: false).fetchServer();
  }

  @override
  Widget build(BuildContext context) => const ServerDetailsFullScreenView(
    body: ServerDetailsForm(),
  );
}
