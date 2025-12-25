import 'package:flutter/material.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/feature/server/server_details/widgets/scope/server_details_scope.dart';
import 'package:trusttunnel/feature/server/server_details/widgets/server_details_discard_changes_dialog.dart';
import 'package:trusttunnel/feature/server/server_details/widgets/server_details_form.dart';
import 'package:trusttunnel/feature/server/server_details/widgets/server_details_full_screen_view.dart';
import 'package:trusttunnel/widgets/common/scaffold_messenger_provider.dart';

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
  Widget build(BuildContext context) => ServerDetailsFullScreenView(
    body: const ServerDetailsForm(),
    onDiscardChanges: (hasChanges) => hasChanges ? _showNotSavedChangesWarning(context) : context.pop(),
  );

  void _showNotSavedChangesWarning(BuildContext context) {
    final parentScaffoldMessenger = ScaffoldMessenger.maybeOf(context);
    
    showDialog(
      context: context,
      builder: (innerContext) => ScaffoldMessengerProvider(
        value: parentScaffoldMessenger ?? ScaffoldMessenger.of(innerContext),
        child: ServerDetailsDiscardChangesDialog(
          onDiscardPressed: context.pop,
        ),
      ),
    );
  }
}
