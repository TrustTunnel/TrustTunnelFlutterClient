import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vpn/common/extensions/context_extensions.dart';
import 'package:vpn/common/localization/localization.dart';
import 'package:vpn/feature/server/server_details/bloc/server_details_bloc.dart';
import 'package:vpn/feature/server/server_details/view/widget/server_details_discard_changes_dialog.dart';
import 'package:vpn/feature/server/server_details/view/widget/server_details_form.dart';
import 'package:vpn/feature/server/server_details/view/widget/server_details_full_screen_view.dart';

class ServerDetailsView extends StatefulWidget {
  const ServerDetailsView({
    super.key,
  });

  @override
  State<ServerDetailsView> createState() => _ServerDetailsViewState();
}

class _ServerDetailsViewState extends State<ServerDetailsView> {
  @override
  Widget build(BuildContext context) => BlocListener<ServerDetailsBloc, ServerDetailsState>(
    listenWhen: (_, current) => current.action != const ServerDetailsAction.none(),
    listener: (context, state) {
      switch (state.action) {
        case ServerDetailsPresentationError(:final error):
          context.showInfoSnackBar(message: error.toLocalizedString(context));
        case ServerDetailsCreated(:final name):
          if (Navigator.canPop(context)) context.pop();
          context.showInfoSnackBar(message: context.ln.serverCreatedSnackbar(name));
          break;
        case ServerDetailsSaved():
          if (Navigator.canPop(context)) context.pop();
          context.showInfoSnackBar(message: context.ln.changesSavedSnackbar);
          break;
        case ServerDetailsDeleted(:final name):
          if (Navigator.canPop(context)) context.pop();
          context.showInfoSnackBar(message: context.ln.serverDeletedSnackbar(name));
        default:
          break;
      }
    },
    child: BlocBuilder<ServerDetailsBloc, ServerDetailsState>(
      buildWhen: (previous, current) => previous.loadingStatus != current.loadingStatus,
      builder: (context, state) {
        if (state.isLoading) return const SizedBox.shrink();

        return ServerDetailsFullScreenView(
          body: const ServerDetailsForm(),
          onDiscardChanges: (hasChanges) => hasChanges ? _showNotSavedChangesWarning(context) : context.pop(),
        );
      },
    ),
  );

  void _showNotSavedChangesWarning(BuildContext context) => showDialog(
    context: context,
    builder: (_) => ServerDetailsDiscardChangesDialog(
      onDiscardPressed: () => context.pop(),
    ),
  );
}
