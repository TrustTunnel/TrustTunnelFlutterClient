import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:trusttunnel/common/assets/asset_icons.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/data/model/server_data.dart';
import 'package:trusttunnel/feature/server/server_details/widgets/scope/server_details_scope.dart';
import 'package:trusttunnel/feature/server/server_details/widgets/scope/server_details_scope_aspect.dart';
import 'package:trusttunnel/feature/server/server_details/widgets/scope/server_details_scope_controller.dart';
import 'package:trusttunnel/feature/server/server_details/widgets/server_details_delete_dialog.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope_controller.dart';
import 'package:trusttunnel/feature/vpn/widgets/vpn_scope.dart';
import 'package:trusttunnel/feature/vpn/widgets/vpn_scope_controller.dart';
import 'package:trusttunnel/widgets/buttons/custom_icon_button.dart';
import 'package:trusttunnel/widgets/common/scaffold_messenger_provider.dart';
import 'package:trusttunnel/widgets/custom_app_bar.dart';
import 'package:trusttunnel/widgets/discard_changes_dialog.dart';

class ServerDetailsFullScreenView extends StatefulWidget {
  final Widget body;

  const ServerDetailsFullScreenView({
    super.key,
    required this.body,
  });

  @override
  State<ServerDetailsFullScreenView> createState() => _ServerDetailsFullScreenViewState();
}

class _ServerDetailsFullScreenViewState extends State<ServerDetailsFullScreenView> {
  late ServersScopeController _serversController;
  late ServerDetailsScopeController _detailsController;
  late VpnScopeController _vpnController;
  late bool _hasChanges;
  late bool _editing;
  late ServerData _data;
  late bool _loading;

  // Keep the form open for writes whose success handler needs it.
  bool _isWriteInProgress = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _serversController = ServersScope.controllerOf(context, listen: false);
    _vpnController = VpnScope.vpnControllerOf(context, listen: false);
    _detailsController = ServerDetailsScope.controllerOf(
      context,
      aspect: ServerDetailsScopeAspect.data,
    );

    _hasChanges = _detailsController.hasChanges;
    _editing = _detailsController.editing;
    _data = _detailsController.data;

    final loadingUpdate = ServerDetailsScope.controllerOf(
      context,
      aspect: ServerDetailsScopeAspect.loading,
    );

    _loading = loadingUpdate.loading;
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_isWriteInProgress && !_hasChanges,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && !_isWriteInProgress) {
        unawaited(DiscardChangesDialog.show(context));
      }
    },
    child: Scaffold(
      appBar: CustomAppBar(
        actions: [
          if (_editing)
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: CustomIconButton.square(
                icon: AssetIcons.delete,
                color: context.colors.error,
                size: 24,
                onPressed: _isWriteInProgress ? null : _showDeleteDialog,
              ),
            ),
        ],
        leadingIconType: AppBarLeadingIconType.back,
        centerTitle: true,
        onBackPressed: () => Navigator.of(context).maybePop(),
        title: _editing ? context.ln.editServer : context.ln.addServer,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _loading ? const SizedBox.shrink() : widget.body,
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: !_isWriteInProgress && _hasChanges ? _submit : null,
              child: Text(
                _editing ? context.ln.save : context.ln.add,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  void _submit() {
    if (!_beginWrite()) {
      return;
    }

    final fetchServers = _serversController.fetchServers;
    final formRoute = ModalRoute.of(context);

    _detailsController.submit(
      onSaved: (name) {
        fetchServers();

        if (mounted && formRoute?.isCurrent == true) {
          _onSubmitted(name);
        }
      },
      onFinished: _finishWrite,
    );
  }

  void _showDeleteDialog() {
    if (_isWriteInProgress) {
      return;
    }

    final parentScaffoldMessenger = ScaffoldMessenger.maybeOf(context);

    unawaited(
      showDialog<void>(
        context: context,
        builder: (innerContext) => ScaffoldMessengerProvider(
          value: parentScaffoldMessenger ?? ScaffoldMessenger.of(innerContext),
          child: ServerDetailsDeleteDialog(
            serverName: _data.name,
            onDeletePressed: _delete,
          ),
        ),
      ),
    );
  }

  void _delete() {
    if (!_beginWrite()) {
      return;
    }

    _detailsController.delete(
      onDeleted: _onDeleted,
      onFinished: _finishWrite,
    );
  }

  bool _beginWrite() {
    if (!mounted || _isWriteInProgress) {
      return false;
    }

    setState(() => _isWriteInProgress = true);

    return true;
  }

  void _finishWrite() {
    if (mounted) {
      setState(() => _isWriteInProgress = false);
    }
  }

  void _onDeleted(String name) {
    if (!mounted) {
      return;
    }

    _vpnController.disconnect();
    _serversController.fetchServers();

    if (_serversController.selectedServer?.id == _detailsController.id) {
      final replacement = _serversController.servers.firstWhereOrNull(
        (server) => server.id != _detailsController.id,
      );
      _serversController.selectServer(replacement?.id);
    }

    if (Navigator.of(context).canPop()) {
      context.pop();
    }
    context.showInfoSnackBar(message: context.ln.serverDeletedSnackbar(name));
  }

  void _onSubmitted(String name) {
    final String snackbarText;

    if (_editing) {
      snackbarText = context.ln.changesSavedSnackbar;
    } else {
      snackbarText = context.ln.serverCreatedSnackbar(name);
    }

    if (Navigator.canPop(context)) {
      context.pop();
    }

    context.showInfoSnackBar(message: snackbarText);
  }
}
