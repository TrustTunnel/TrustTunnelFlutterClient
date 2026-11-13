import 'package:flutter/material.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/data/model/routing_mode.dart';
import 'package:trusttunnel/feature/routing/routing/widgets/scope/routing_scope.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope.dart';
import 'package:trusttunnel/feature/settings/ru_bypass/widgets/scope/ru_bypass_aspect.dart';
import 'package:trusttunnel/feature/settings/ru_bypass/widgets/scope/ru_bypass_scope.dart';
import 'package:trusttunnel/widgets/common/custom_switch_tile.dart';
import 'package:trusttunnel/widgets/custom_app_bar.dart';
import 'package:trusttunnel/widgets/progress_wrapper.dart';
import 'package:trusttunnel/widgets/scaffold_wrapper.dart';

/// {@template ru_bypass_screen_view}
/// Runet bypass settings: keep Russian websites, services and networks
/// outside the VPN tunnel.
/// {@endtemplate}
class RuBypassScreenView extends StatelessWidget {
  const RuBypassScreenView({super.key});

  /// Whether the routing profile of the currently selected server operates
  /// in Bypass (selective) mode, where everything bypasses the VPN by default
  /// and the Runet bypass merge has no effect.
  bool _isProfileInBypassMode(BuildContext context) {
    try {
      final server = ServersScope.controllerOf(context, listen: false).selectedServer;
      if (server == null) {
        return false;
      }

      final profile = RoutingScope.controllerOf(context, listen: false).routingList.firstWhere(
        (profile) => profile.id == server.serverData.routingProfileId,
      );

      return profile.data.defaultMode == RoutingMode.bypass;
    } catch (_) {
      // Scope or profile not found (e.g. no servers yet).
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = RuBypassScope.controllerOf(context, aspect: RuBypassAspect.data);
    final profileInBypassMode = _isProfileInBypassMode(context);

    return ScaffoldWrapper(
      child: Scaffold(
        appBar: CustomAppBar(
          title: context.ln.ruBypass,
        ),
        body: ProgressWrapper(
          isLoading: controller.loading,
          child: ListView(
            children: [
              if (profileInBypassMode)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ColoredBox(
                    color: context.theme.colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        context.ln.ruBypassBypassModeWarning,
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: context.theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ),
                ),
              CustomSwitchTile(
                title: context.ln.ruBypass,
                subtitle: context.ln.ruBypassSubtitle,
                value: controller.enabled,
                onChanged: controller.changeEnabled,
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      context.ln.ruBypassHowItWorksTitle,
                      style: context.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.ln.ruBypassHowItWorks,
                      style: context.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      context.ln.ruBypassStatusTitle,
                      style: context.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      controller.lastUpdateDate == null
                          ? context.ln.ruBypassNeverUpdated
                          : context.ln.ruBypassLastUpdated(controller.lastUpdateDate!),
                      style: context.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.ln.ruBypassCidrCount(controller.cidrCount),
                      style: context.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.tonalIcon(
                      onPressed: controller.loading ? null : () => _updateLists(context),
                      icon: const Icon(Icons.download),
                      label: Text(context.ln.ruBypassUpdateNow),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.ln.ruBypassUpdateSource,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (controller.error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        controller.error?.toLocalizedString(context) ?? '',
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: context.theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _updateLists(BuildContext context) {
    final controller = RuBypassScope.controllerOf(context, listen: false);
    controller.updateLists(
      (cidrCount) => context.showInfoSnackBar(
        message: context.ln.ruBypassUpdated(cidrCount),
      ),
    );
  }
}
