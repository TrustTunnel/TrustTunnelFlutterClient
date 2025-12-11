import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vpn/common/assets/asset_icons.dart';
import 'package:vpn/common/extensions/context_extensions.dart';
import 'package:vpn/common/localization/localization.dart';
import 'package:vpn/data/model/routing_mode.dart';
import 'package:vpn/feature/routing/routing_details/bloc/routing_details_bloc.dart';
import 'package:vpn/feature/routing/routing_details/view/widget/routing_details_change_routing_dialog.dart';
import 'package:vpn/feature/routing/routing_details/view/widget/routing_details_delete_rules_dialog.dart';
import 'package:vpn/view/custom_icon.dart';

class RoutingDetailsScreenAppBarAction extends StatelessWidget {
  const RoutingDetailsScreenAppBarAction({
    super.key,
  });

  @override
  Widget build(BuildContext context) => PopupMenuButton(
    icon: CustomIcon.medium(
      icon: AssetIcons.moreVert,
    ),
    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
      PopupMenuItem<String>(
        onTap: () => _onChangeDefaultRoutingMode(context),
        child: Row(
          children: [
            CustomIcon.medium(
              icon: AssetIcons.update,
            ),
            const SizedBox(width: 12),
            Text(
              context.ln.changeDefaultRoutingMode,
              style: context.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
      PopupMenuItem<String>(
        onTap: () => _onDeleteRules(context),
        child: Row(
          children: [
            CustomIcon.medium(
              icon: AssetIcons.delete,
              color: context.colors.error,
            ),
            const SizedBox(width: 12),
            Text(
              context.ln.deleteAllRules,
              style: context.textTheme.bodyLarge?.copyWith(
                color: context.colors.error,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  void _onDeleteRules(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => RoutingDetailsDeleteRulesDialog(
        onDeletePressed: () => _onDeleteRulesSubmit(context: context),
        profileName: context.read<RoutingDetailsBloc>().state.routingName,
      ),
    );
  }

  void _onChangeDefaultRoutingMode(BuildContext context) => showDialog(
    context: context,
    builder: (_) => RoutingDetailsChangeRoutingDialog(
      onSavePressed: (mode) => _onChangeDefaultRoutingModeSubmit(context: context, mode: mode),
      currentRoutingMode: context.read<RoutingDetailsBloc>().state.data.defaultMode,
    ),
  );

  void _onDeleteRulesSubmit({
    required BuildContext context,
  }) => context.read<RoutingDetailsBloc>().add(
    const RoutingDetailsEvent.clear(),
  );

  void _onChangeDefaultRoutingModeSubmit({
    required BuildContext context,
    required RoutingMode mode,
  }) => context.read<RoutingDetailsBloc>().add(
    RoutingDetailsEvent.changeDefaultMode(
      mode,
    ),
  );
}
