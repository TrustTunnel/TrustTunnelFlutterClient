import 'package:flutter/material.dart';
import 'package:vpn/common/assets/asset_icons.dart';
import 'package:vpn/common/extensions/context_extensions.dart';
import 'package:vpn/common/localization/localization.dart';
import 'package:vpn/view/custom_icon.dart';

abstract class NavigationScreenUtils {
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
