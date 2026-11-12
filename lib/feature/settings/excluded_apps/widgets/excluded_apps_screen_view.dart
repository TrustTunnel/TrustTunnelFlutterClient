import 'package:flutter/material.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/data/model/installed_app.dart';
import 'package:trusttunnel/data/presets/ru_bypass_preset.dart';
import 'package:trusttunnel/feature/settings/excluded_apps/widgets/excluded_apps_button_section.dart';
import 'package:trusttunnel/feature/settings/excluded_apps/widgets/scope/excluded_apps_aspect.dart';
import 'package:trusttunnel/feature/settings/excluded_apps/widgets/scope/excluded_apps_scope.dart';
import 'package:trusttunnel/widgets/common/custom_checkbox_list_tile.dart';
import 'package:trusttunnel/widgets/common/scaffold_messenger_provider.dart';
import 'package:trusttunnel/widgets/custom_app_bar.dart';
import 'package:trusttunnel/widgets/discard_changes_dialog.dart';
import 'package:trusttunnel/widgets/inputs/custom_text_field.dart';
import 'package:trusttunnel/widgets/scaffold_wrapper.dart';

/// {@template excluded_apps_screen_view}
/// Per-app VPN exclusions: pick applications whose traffic must bypass
/// the VPN tunnel.
/// {@endtemplate}
class ExcludedAppsScreenView extends StatefulWidget {
  const ExcludedAppsScreenView({super.key});

  @override
  State<ExcludedAppsScreenView> createState() => _ExcludedAppsScreenViewState();
}

class _ExcludedAppsScreenViewState extends State<ExcludedAppsScreenView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showSystemApps = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ExcludedAppsScope.controllerOf(context, aspect: ExcludedAppsAspect.data);
    final hasChanges = controller.hasChanges;

    return PopScope(
      canPop: !hasChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _showNotSavedChangesWarning(context);
        }
      },
      child: ScaffoldWrapper(
        child: Scaffold(
          appBar: CustomAppBar(
            title: context.ln.excludedApps,
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: CustomTextField(
                  controller: _searchController,
                  hint: context.ln.excludedAppsSearchHint,
                  onChanged: (value) => setState(() => _searchQuery = value.trim().toLowerCase()),
                ),
              ),
              Expanded(
                child: controller.appsLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _AppList(
                        searchQuery: _searchQuery,
                        showSystemApps: _showSystemApps,
                        onShowSystemAppsChanged: (value) => setState(() => _showSystemApps = value),
                      ),
              ),
              const ExcludedAppsButtonSection(),
            ],
          ),
        ),
      ),
    );
  }

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

class _AppList extends StatelessWidget {
  final String searchQuery;
  final bool showSystemApps;
  final ValueChanged<bool> onShowSystemAppsChanged;

  const _AppList({
    required this.searchQuery,
    required this.showSystemApps,
    required this.onShowSystemAppsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final controller = ExcludedAppsScope.controllerOf(context, listen: false);
    final installedApps = controller.installedApps;
    final excludedApps = controller.excludedApps;

    if (installedApps.isEmpty) {
      return Center(child: Text(context.ln.excludedAppsUnavailable));
    }

    final presetPackages = RuBypassPreset.apps.map((app) => app.packageName).toSet();
    final recommended = installedApps.where((app) => presetPackages.contains(app.packageName)).toList(growable: false);
    final regular = installedApps
        .where((app) => !presetPackages.contains(app.packageName))
        .where((app) => showSystemApps || !app.isSystem)
        .toList(growable: false);

    final filteredRecommended = _filter(recommended);
    final filteredRegular = _filter(regular);
    final recommendedSelectedCount = recommended.where((app) => excludedApps.contains(app.packageName)).length;

    return Scrollbar(
      child: ListView(
        children: [
          if (filteredRecommended.isNotEmpty) ...[
            _SectionHeader(
              title: context.ln.excludedAppsRecommended,
              action: FilledButton.tonal(
                onPressed: recommendedSelectedCount == recommended.length
                    ? null
                    : () => _selectAllRecommended(context, recommended),
                child: Text(context.ln.excludedAppsSelectAllRecommended),
              ),
            ),
            ...filteredRecommended.map((app) => _AppTile(app: app)),
          ],
          _SectionHeader(
            title: context.ln.excludedAppsAll,
            action: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.ln.excludedAppsShowSystem,
                  style: context.textTheme.bodyMedium,
                ),
                Switch(
                  value: showSystemApps,
                  onChanged: onShowSystemAppsChanged,
                ),
              ],
            ),
          ),
          if (filteredRegular.isEmpty && filteredRecommended.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(context.ln.excludedAppsNothingFound),
            ),
          ...filteredRegular.map((app) => _AppTile(app: app)),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  List<InstalledApp> _filter(List<InstalledApp> apps) {
    if (searchQuery.isEmpty) {
      return apps;
    }

    return apps
        .where(
          (app) =>
              app.label.toLowerCase().contains(searchQuery) || app.packageName.toLowerCase().contains(searchQuery),
        )
        .toList(growable: false);
  }

  void _selectAllRecommended(BuildContext context, List<InstalledApp> recommended) {
    final controller = ExcludedAppsScope.controllerOf(context, listen: false);
    final merged = {...controller.excludedApps, ...recommended.map((app) => app.packageName)}.toList();
    controller.changeExcludedApps(merged);

    context.showInfoSnackBar(message: context.ln.excludedAppsRecommendedAdded(recommended.length));
  }
}

class _AppTile extends StatelessWidget {
  final InstalledApp app;

  const _AppTile({required this.app});

  @override
  Widget build(BuildContext context) {
    final controller = ExcludedAppsScope.controllerOf(context, listen: false);
    final checked = controller.excludedApps.contains(app.packageName);

    return CustomCheckboxListTile(
      value: checked,
      onChanged: (_) => controller.toggleApp(app.packageName),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            app.label,
            style: context.textTheme.bodyLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            app.packageName,
            style: context.textTheme.bodySmall?.copyWith(color: context.theme.colorScheme.onSurfaceVariant),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? action;

  const _SectionHeader({
    required this.title,
    this.action,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: context.textTheme.titleMedium,
          ),
        ),
        ?action,
      ],
    ),
  );
}
