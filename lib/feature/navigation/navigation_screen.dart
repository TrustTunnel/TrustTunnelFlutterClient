import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/logging/observers/logging_navigator_observer.dart';
import 'package:trusttunnel/common/router/app_route.dart';
import 'package:trusttunnel/common/router/app_routes.dart';
import 'package:trusttunnel/common/utils/macos_app_window_utils.dart';
import 'package:trusttunnel/common/utils/navigation_utils.dart';
import 'package:trusttunnel/data/model/server_data.dart';
import 'package:trusttunnel/feature/deep_link/deep_link_scope.dart';
import 'package:trusttunnel/feature/menu_bar/widgets/tray_menu_scope.dart';
import 'package:trusttunnel/feature/navigation/widgets/custom_navigation_rail.dart';
import 'package:trusttunnel/feature/routing/routing/widgets/routing_screen.dart';
import 'package:trusttunnel/feature/server/server_details/widgets/server_details_popup.dart';
import 'package:trusttunnel/feature/server/servers/widget/servers_screen.dart';
import 'package:trusttunnel/feature/settings/app_logging/widgets/scope/app_logging_scope.dart';
import 'package:trusttunnel/feature/settings/logs_manager/widgets/scope/logs_manager_scope.dart';
import 'package:trusttunnel/feature/settings/query_log/widgets/query_log_screen.dart';
import 'package:trusttunnel/feature/settings/settings/settings_screen.dart';
import 'package:trusttunnel/widgets/common/scaffold_messenger_provider.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final ValueNotifier<int> _selectedTabNotifier = ValueNotifier(0);
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final LoggingNavigatorObserver _navigatorObserver;

  ServerData? _deepLinkData;

  @override
  void initState() {
    super.initState();
    _navigatorObserver = LoggingNavigatorObserver(
      navigatorName: 'navigation',
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final fetchedDeepLink = DeepLinkScope.of(context).deepLinkData;
    if (_deepLinkData != fetchedDeepLink) {
      _deepLinkData = fetchedDeepLink;
      if (_deepLinkData != null) {
        _navigatorKey.currentState?.popUntil((f) => f.isFirst);
        unawaited(
          _setTabRoute(
            0,
            deepLinkData: _deepLinkData,
            force: true,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => LogsManagerScope(
    child: AppLoggingScope(
      child: TrayMenuScope(
        onRouteRequested: _openRouteFromTray,
        child: ColoredBox(
          color: context.colors.background,
          child: SafeArea(
            right: false,
            bottom: false,
            left: false,
            child: Scaffold(
              primary: false,
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
        ),
      ),
    ),
  );

  // TODO: Make navigator works with deeplink in right way
  // Konstantin Gorynin <k.gorynin@adguard.com>, 31 March 2026
  Widget getScreenByIndex(
    int selectedIndex, {
    ServerData? deepLinkData,
  }) => switch (selectedIndex) {
    0 => ServersScreen(
      deepLinkData: deepLinkData,
    ),
    1 => const RoutingScreen(),
    2 => const SettingsScreen(),
    _ => throw Exception('Invalid index: $selectedIndex'),
  };

  Widget _getContent() => NavigatorPopHandler(
    onPopWithResult: (_) => _navigatorKey.currentState!.maybePop(),
    child: Navigator(
      key: _navigatorKey,
      observers: [_navigatorObserver],
      onGenerateInitialRoutes: (_, _) => [
        PageRouteBuilder(
          settings: AppRoutes.servers.settings,
          pageBuilder: (context, animation, secondaryAnimation) => const ServersScreen(),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      ],
    ),
  );

  void _onDestinationSelected(int selectedIndex, {ServerData? deepLinkData}) {
    unawaited(
      _setTabRoute(
        selectedIndex,
        deepLinkData: deepLinkData,
      ),
    );
  }

  Future<void> _openRouteFromTray(AppRoute route) async {
    await MacOSAppWindowUtils.showMainWindow();

    switch (route) {
      case final requestedRoute when requestedRoute == AppRoutes.servers:
        await _setTabRoute(
          0,
          force: true,
        );
        return;
      case final requestedRoute when requestedRoute == AppRoutes.routing:
        await _setTabRoute(
          1,
          force: true,
        );
        return;
      case final requestedRoute when requestedRoute == AppRoutes.settings:
        await _setTabRoute(
          2,
          force: true,
        );
        return;
      case final requestedRoute when requestedRoute == AppRoutes.serverDetails:
        await _setTabRoute(
          0,
          force: true,
        );
        await _pushOnInnerNavigator(
          const ServerDetailsPopUp(),
          route: AppRoutes.serverDetails,
        );
        return;
      case final requestedRoute when requestedRoute == AppRoutes.queryLog:
        await _setTabRoute(
          2,
          force: true,
        );
        await _pushOnInnerNavigator(
          const QueryLogScreen(),
          route: AppRoutes.queryLog,
        );
        return;
      default:
        return;
    }
  }

  Future<void> _setTabRoute(
    int selectedIndex, {
    ServerData? deepLinkData,
    bool force = false,
  }) async {
    final shouldNavigate = force || _selectedTabNotifier.value != selectedIndex || deepLinkData != null;
    if (!shouldNavigate) {
      return;
    }

    final navigatorState = _navigatorKey.currentState;
    if (navigatorState == null) {
      return;
    }

    _selectedTabNotifier.value = selectedIndex;
    navigatorState.pushAndRemoveUntil(
      PageRouteBuilder(
        settings: AppRoutes.byNavigationIndex(selectedIndex).settings,
        pageBuilder:
            (
              context,
              animation,
              secondaryAnimation,
            ) => getScreenByIndex(
              selectedIndex,
              deepLinkData: deepLinkData,
            ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
      (_) => false,
    );

    await SchedulerBinding.instance.endOfFrame;
  }

  Future<T?> _pushOnInnerNavigator<T extends Object?>(
    Widget widget, {
    AppRoute? route,
  }) async {
    final navigatorState = _navigatorKey.currentState;
    if (navigatorState == null) {
      return null;
    }

    final parentScaffoldMessenger = ScaffoldMessenger.maybeOf(
      navigatorState.context,
    );

    return navigatorState.push<T>(
      MaterialPageRoute<T>(
        settings: route?.settings ?? RouteSettings(name: widget.runtimeType.toString()),
        builder: (innerContext) => ScaffoldMessengerProvider(
          value: parentScaffoldMessenger ?? ScaffoldMessenger.of(innerContext),
          child: widget,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _selectedTabNotifier.dispose();
    super.dispose();
  }
}
