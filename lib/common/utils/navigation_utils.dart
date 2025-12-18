import 'package:flutter/material.dart';
import 'package:trusttunnel/common/assets/asset_icons.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/widgets/custom_icon.dart';

abstract class NavigationUtils {
  static List<Map<String, Object>> getDestinations(BuildContext context) => [
    {
      'icon': AssetIcons.dns,
      'label': context.ln.servers,
    },
    {
      'icon': AssetIcons.route,
      'label': context.ln.routing,
    },
    {
      'icon': AssetIcons.settings,
      'label': context.ln.settings,
    },
  ];

  static List<NavigationRailDestination> getNavigationRailDestinations(
    BuildContext context,
  ) => getDestinations(context)
      .map(
        (e) => NavigationRailDestination(
          icon: CustomIcon.medium(
            icon: e['icon'] as IconData,
          ),
          label: Text(
            e['label'].toString(),
            textAlign: TextAlign.center,
            style: context.textTheme.labelMedium,
          ),
        ),
      )
      .toList();

  static List<NavigationDestination> getBottomNavigationDestinations(
    BuildContext context,
  ) => getDestinations(context)
      .map(
        (e) => NavigationDestination(
          icon: CustomIcon.medium(
            icon: e['icon'] as IconData,
          ),
          label: e['label'].toString(),
        ),
      )
      .toList();
}
