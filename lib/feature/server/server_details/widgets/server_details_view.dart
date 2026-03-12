import 'package:flutter/material.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/feature/server/server_details/widgets/scope/server_details_scope.dart';
import 'package:trusttunnel/feature/server/server_details/widgets/scope/server_details_scope_aspect.dart';
import 'package:trusttunnel/feature/server/server_details/widgets/server_details_form.dart';
import 'package:trusttunnel/feature/server/server_details/widgets/server_details_full_screen_view.dart';
import 'package:trusttunnel/widgets/common/scaffold_messenger_provider.dart';
import 'package:trusttunnel/widgets/discard_changes_dialog.dart';

class ServerDetailsView extends StatefulWidget {
  const ServerDetailsView({
    super.key,
  });

  @override
  State<ServerDetailsView> createState() => _ServerDetailsViewState();
}

class _ServerDetailsViewState extends State<ServerDetailsView> {
  late bool hasChanges;
  @override
  void initState() {
    super.initState();
    ServerDetailsScope.controllerOf(context, listen: false).fetchServer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    hasChanges = ServerDetailsScope.controllerOf(context, aspect: ServerDetailsScopeAspect.data).hasChanges;
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !hasChanges,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) {
        _showNotSavedChangesWarning(context);
      }
    },
    child: const ServerDetailsFullScreenView(
      body: ServerDetailsForm(),
    ),
  );

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
