import 'package:flutter/material.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/utils/navigation_utils.dart';
import 'package:trusttunnel/data/model/server_data.dart';
import 'package:trusttunnel/feature/deep_link/deep_link_scope.dart';
import 'package:trusttunnel/feature/navigation/widgets/custom_navigation_rail.dart';
import 'package:trusttunnel/feature/routing/routing/widgets/routing_screen.dart';
import 'package:trusttunnel/feature/server/server_details/widgets/server_details_popup.dart';
import 'package:trusttunnel/feature/server/servers/widget/servers_screen.dart';
import 'package:trusttunnel/feature/settings/settings/settings_screen.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final ValueNotifier<int> _selectedTabNotifier = ValueNotifier(0);
  final _navigatorKey = GlobalKey<NavigatorState>();

  ServerData? _deepLinkData;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final fetchedDeepLink = DeepLinkScope.of(context).deepLinkData;
    if (fetchedDeepLink != _deepLinkData) {
      _deepLinkData = fetchedDeepLink;
      _navigatorKey.currentState?.popUntil((f) => f.isFirst);
      _selectedTabNotifier.value = 0;
      _navigatorKey.currentContext?.push(
        ServerDetailsPopUp.preloaded(
          preloadedData: fetchedDeepLink,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.colors.background,
    child: SafeArea(
      right: false,
      bottom: false,
      left: false,
      child: Scaffold(
        backgroundColor: context.colors.backgroundSystem,
        body: SafeArea(
          top: false,
          child: context.isMobileBreakpoint
              ? _getContent()
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ValueListenableBuilder(
                      valueListenable: _selectedTabNotifier,
                      builder: (context, index, _) => CustomNavigationRail(
                        selectedIndex: index,
                        onDestinationSelected: _onDestinationSelected,
                        destinations: NavigationUtils.getNavigationRailDestinations(context),
                      ),
                    ),
                    Expanded(
                      child: _getContent(),
                    ),
                  ],
                ),
        ),
        bottomNavigationBar: context.isMobileBreakpoint
            ? ValueListenableBuilder(
                valueListenable: _selectedTabNotifier,
                builder: (context, index, _) => SafeArea(
                  child: NavigationBar(
                    selectedIndex: index,
                    onDestinationSelected: _onDestinationSelected,
                    destinations: NavigationUtils.getBottomNavigationDestinations(context),
                  ),
                ),
              )
            : null,
      ),
    ),
  );

  Widget getScreenByIndex(int selectedIndex) => switch (selectedIndex) {
    0 => const ServersScreen(),
    1 => const RoutingScreen(),
    2 => const SettingsScreen(),
    _ => throw Exception('Invalid index: $selectedIndex'),
  };

  Widget _getContent() => NavigatorPopHandler(
    onPop: () => _navigatorKey.currentState!.pop(),
    child: Navigator(
      key: _navigatorKey,
      onGenerateInitialRoutes: (_, __) => [
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const ServersScreen(),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      ],
    ),
  );

  void _onDestinationSelected(int selectedIndex) {
    if (_selectedTabNotifier.value != selectedIndex) {
      _selectedTabNotifier.value = selectedIndex;
      _navigatorKey.currentState!.pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => getScreenByIndex(selectedIndex),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
        (_) => false,
      );
    }
  }
}
