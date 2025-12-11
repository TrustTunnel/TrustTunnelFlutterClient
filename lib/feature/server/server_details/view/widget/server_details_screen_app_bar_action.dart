import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vpn/common/assets/asset_icons.dart';
import 'package:vpn/common/extensions/context_extensions.dart';
import 'package:vpn/feature/server/server_details/bloc/server_details_bloc.dart';
import 'package:vpn/feature/server/server_details/view/widget/server_details_delete_dialog.dart';
import 'package:vpn/view/buttons/custom_icon_button.dart';

class ServerDetailsScreenAppBarAction extends StatelessWidget {
  const ServerDetailsScreenAppBarAction({
    super.key,
  });

  @override
  Widget build(BuildContext context) => BlocBuilder<ServerDetailsBloc, ServerDetailsState>(
    builder: (context, state) => state.isEditing
        ? CustomIconButton.square(
            icon: AssetIcons.delete,
            color: context.colors.error,
            size: 24,
            onPressed: () => _showDeleteDialog(
              context,
              serverName: state.initialData.serverName,
            ),
          )
        : const SizedBox(),
  );

  void _showDeleteDialog(BuildContext context, {required String serverName}) => showDialog(
    context: context,
    builder: (_) => ServerDetailsDeleteDialog(
      onDeletePressed: () => _onDeleteServerSubmit(context),
      serverName: serverName,
    ),
  );

  void _onDeleteServerSubmit(
    BuildContext context,
  ) => context.read<ServerDetailsBloc>().add(
    const ServerDetailsEvent.delete(),
  );
}
