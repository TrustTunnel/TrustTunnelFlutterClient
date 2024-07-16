import 'package:flutter/material.dart';
import 'package:vpn/common/extensions/context_extensions.dart';
import 'package:vpn/feature/navigation/view/common/navigation_screen_utils.dart';
import 'package:vpn/feature/navigation/view/widgets/custom_navigation_rail.dart';
import 'package:vpn/feature/routing/routing/view/routing_screen.dart';
import 'package:vpn/feature/server/servers/view/servers_screen.dart';
import 'package:vpn/feature/settings/settings_screen.dart';
import 'package:vpn/feature/test/test_screen.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final ValueNotifier<int> _selectedTabNotifier = ValueNotifier(0);
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context.colors.background2,
        body: context.isMobileBreakpoint
            ? _getContent()
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ValueListenableBuilder(
                    valueListenable: _selectedTabNotifier,
                    builder: (context, index, _) => CustomNavigationRail(
                      selectedIndex: index,
                      onDestinationSelected: _onDestinationSelected,
                      destinations: NavigationScreenUtils.getNavigationRailDestinations(context),
                    ),
                  ),
                  Expanded(
                    child: _getContent(),
                  ),
                ],
              ),
        bottomNavigationBar: context.isMobileBreakpoint
            ? ValueListenableBuilder(
                valueListenable: _selectedTabNotifier,
                builder: (context, index, _) => NavigationBar(
                  selectedIndex: index,
                  onDestinationSelected: _onDestinationSelected,
                  destinations: NavigationScreenUtils.getBottomNavigationDestinations(context),
                ),
              )
            : null,
      );

  Widget _getContent() => Navigator(
        key: _navigatorKey,
        onGenerateInitialRoutes: (_, __) => [
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const ServersScreen(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        ],
      );

  void _onDestinationSelected(int selectedIndex) {
    if (_selectedTabNotifier.value != selectedIndex) {
      _selectedTabNotifier.value = selectedIndex;

      _navigatorKey.currentState!.pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => getScreenByIndex(selectedIndex),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    }
  }

  Widget getScreenByIndex(int selectedIndex) => switch (selectedIndex) {
        0 => const ServersScreen(),
        1 => const RoutingScreen(),
        2 => const SettingsScreen(),
        3 => const TestScreen(),
        _ => throw Exception('Invalid index: $selectedIndex'),
      };
}
