import 'package:flutter/material.dart';
import 'package:trusttunnel/common/assets/asset_icons.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/common/utils/routing_profile_utils.dart';
import 'package:trusttunnel/data/model/routing_profile.dart';
import 'package:trusttunnel/feature/routing/routing/widgets/routing_card.dart';
import 'package:trusttunnel/feature/routing/routing/widgets/scope/routing_scope.dart';
import 'package:trusttunnel/feature/routing/routing/widgets/scope/routing_scope_aspect.dart';
import 'package:trusttunnel/feature/routing/routing/widgets/scope/routing_scope_controller.dart';
import 'package:trusttunnel/feature/routing/routing_details/widgets/routing_details_screen.dart';
import 'package:trusttunnel/widgets/buttons/custom_floating_action_button.dart';
import 'package:trusttunnel/widgets/buttons/custom_icon_button.dart';
import 'package:trusttunnel/widgets/common/delete_selected_dialog.dart';
import 'package:trusttunnel/widgets/common/scaffold_messenger_provider.dart';
import 'package:trusttunnel/widgets/custom_app_bar.dart';
import 'package:trusttunnel/widgets/scaffold_wrapper.dart';

class RoutingScreenView extends StatefulWidget {
  const RoutingScreenView({super.key});

  @override
  State<RoutingScreenView> createState() => _RoutingScreenViewState();
}

class _RoutingScreenViewState extends State<RoutingScreenView> {
  late List<RoutingProfile> _routingProfiles;

  bool _selectionMode = false;
  final Set<String> _selectedProfileIds = {};

  @override
  void initState() {
    super.initState();
    _routingProfiles = RoutingScope.controllerOf(context, listen: false).routingList;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routingProfiles = RoutingScope.controllerOf(
      context,
      aspect: RoutingScopeAspect.profiles,
    ).routingList;

    if (_selectedProfileIds.isNotEmpty) {
      final availableIds = _routingProfiles.map((profile) => profile.id).toSet();
      _selectedProfileIds.removeWhere((id) => !availableIds.contains(id));

      if (_selectedProfileIds.isEmpty) {
        _selectionMode = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) => ScaffoldWrapper(
    child: ScaffoldMessenger(
      child: PopScope(
        canPop: !_selectionMode,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _selectionMode) {
            _exitSelectionMode();
          }
        },
        child: Scaffold(
          appBar: _selectionMode
              ? _buildSelectionAppBar(context)
              : CustomAppBar(
                  title: context.ln.routing,
                ),
          body: ListView.builder(
            itemBuilder: (context, index) => Column(
              children: [
                RoutingCard(
                  routingProfile: _routingProfiles[index],
                  selectionMode: _selectionMode,
                  selected: _selectedProfileIds.contains(_routingProfiles[index].id),
                  onSelectionToggle: (selected) => _toggleProfileSelection(
                    _routingProfiles[index].id,
                    selected,
                  ),
                  onLongPress: () => _enterSelectionMode(_routingProfiles[index], context),
                ),
                index == _routingProfiles.length - 1 ? const SizedBox(height: 80) : const Divider(),
              ],
            ),
            itemCount: _routingProfiles.length,
          ),
          floatingActionButton: !_selectionMode
              ? Builder(
                  builder: (context) => CustomFloatingActionButton.extended(
                    icon: AssetIcons.add,
                    onPressed: () => _pushRoutingProfileDetailsScreen(context),
                    label: context.ln.addProfile,
                  ),
                )
              : null,
        ),
      ),
    ),
  );

  CustomAppBar _buildSelectionAppBar(BuildContext context) => CustomAppBar(
    title: context.ln.selectedItemsCount(_selectedProfileIds.length),
    leadingIconType: AppBarLeadingIconType.close,
    onBackPressed: _exitSelectionMode,
    actions: [
      TextButton(
        onPressed: _toggleSelectAllProfiles,
        child: Text(_allProfilesSelected ? context.ln.deselectAll : context.ln.selectAll),
      ),
      CustomIconButton(
        icon: AssetIcons.delete,
        color: context.colors.error,
        onPressed: _selectedProfileIds.isEmpty ? null : _deleteSelectedProfiles,
      ),
    ],
  );

  void _enterSelectionMode(RoutingProfile profile, BuildContext context) {
    if (RoutingProfileUtils.isDefaultRoutingProfile(profile: profile)) {
      context.showInfoSnackBar(message: context.ln.defaultProfileCannotBeDeleted);
      return;
    }

    if (_selectionMode && _selectedProfileIds.contains(profile.id)) {
      return;
    }

    setState(() {
      _selectionMode = true;
      _selectedProfileIds.add(profile.id);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedProfileIds.clear();
    });
  }

  void _toggleProfileSelection(String profileId, bool selected) {
    setState(() {
      if (selected) {
        _selectedProfileIds.add(profileId);
      } else {
        _selectedProfileIds.remove(profileId);
      }

      if (_selectedProfileIds.isEmpty) {
        _selectionMode = false;
      }
    });
  }

  List<String> get _selectableProfileIds => _routingProfiles
      .where((profile) => !RoutingProfileUtils.isDefaultRoutingProfile(profile: profile))
      .map((profile) => profile.id)
      .toList();

  bool get _allProfilesSelected => _selectedProfileIds.length == _selectableProfileIds.length;

  void _toggleSelectAllProfiles() {
    setState(() {
      if (_allProfilesSelected) {
        _selectedProfileIds.clear();
        _selectionMode = false;
      } else {
        _selectedProfileIds
          ..clear()
          ..addAll(_selectableProfileIds);
      }
    });
  }

  Future<void> _deleteSelectedProfiles() async {
    final controller = RoutingScope.controllerOf(context, listen: false);
    final count = _selectedProfileIds.length;
    final title = context.ln.deleteSelectedProfilesDialogTitle;
    final description = context.ln.deleteSelectedProfilesDialogDescription(count);
    final parentScaffoldMessenger = ScaffoldMessenger.maybeOf(context);

    await showDialog(
      context: context,
      builder: (innerContext) => ScaffoldMessengerProvider(
        value: parentScaffoldMessenger ?? ScaffoldMessenger.of(innerContext),
        child: DeleteSelectedDialog(
          title: title,
          description: description,
          onDeletePressed: () => _confirmDeleteProfiles(controller, count),
        ),
      ),
    );
  }

  void _confirmDeleteProfiles(RoutingScopeController controller, int count) {
    final profileIds = _selectedProfileIds.toList();

    controller.deleteProfiles(
      profileIds,
      () {
        if (!mounted) {
          return;
        }

        setState(() {
          _selectionMode = false;
          _selectedProfileIds.clear();
        });

        context.showInfoSnackBar(message: context.ln.profilesDeletedSnackbar(count));
      },
      () => _showOperationError(context),
    );
  }

  void _showOperationError(BuildContext context) {
    if (!mounted) {
      return;
    }

    context.showInfoSnackBar(message: context.ln.somethingWentWrongSnackbar);
  }

  void _pushRoutingProfileDetailsScreen(BuildContext context) async {
    await context.push(
      const RoutingDetailsScreen(),
    );

    if (context.mounted) {
      RoutingScope.controllerOf(context, listen: false).fetchProfiles();
    }
  }
}
