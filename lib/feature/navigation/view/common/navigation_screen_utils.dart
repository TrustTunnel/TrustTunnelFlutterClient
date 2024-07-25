import 'package:flutter/material.dart';
import 'package:vpn/common/assets/asset_icons.dart';
import 'package:vpn/common/extensions/common_extensions.dart';
import 'package:vpn/common/extensions/context_extensions.dart';
import 'package:vpn/common/localization/localization.dart';
import 'package:vpn/view/custom_svg_picture.dart';

abstract class NavigationScreenUtils {
  static List<Map<String, String>> getDestinations(BuildContext context) => [
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
  ) =>
      getDestinations(context)
          .map(
            (e) => NavigationRailDestination(
              icon: CustomSvgPicture(
                icon: e['icon'].toString(),
                size: 24,
                color: context.colors.contrast1,
              ),
              label: Text(
                e['label'].toString(),
                textAlign: TextAlign.center,
              ).labelMedium(context),
            ),
          )
          .toList();

  static List<NavigationDestination> getBottomNavigationDestinations(
    BuildContext context,
  ) =>
      getDestinations(context)
          .map(
            (e) => NavigationDestination(
              icon: CustomSvgPicture(
                icon: e['icon'].toString(),
                size: 24,
                color: context.colors.contrast1,
              ),
              label: e['label'].toString(),
            ),
          )
          .toList();
}
