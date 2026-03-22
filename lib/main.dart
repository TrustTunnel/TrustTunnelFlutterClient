import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart' hide Router;
import 'package:flutter/material.dart';
import 'package:trusttunnel/di/model/initialization_helper.dart';
import 'package:trusttunnel/di/widgets/dependency_scope.dart';
import 'package:trusttunnel/feature/app/app.dart';
import 'package:trusttunnel/feature/deep_link/deep_link_scope.dart';
import 'package:trusttunnel/feature/routing/routing/widgets/scope/routing_scope.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/scope/excluded_routes_scope.dart';
import 'package:trusttunnel/feature/vpn/widgets/vpn_scope.dart';
import 'package:trusttunnel/feature/vpn/widgets/vpn_update_manager.dart';

// 1. ADD THIS IMPORT
import 'samsung_routine_handler.dart';

void main() => runZonedGuarded(
  () async {
    // 2. ADD THIS LINE: Required when using plugins before runApp
    WidgetsFlutterBinding.ensureInitialized();
    
    final initializationResult = await InitializationHelperIo().init();

    // 3. ADD THIS BLOCK: Initialize the Samsung Routine Handler
    SamsungRoutineHandler.init(() {
      // Access the VPN repository directly from the initializationResult
      final vpnRepo = initializationResult.repositoryFactory.vpnRepository;
      
      // Connect to the specific server. You may need to adapt this slightly 
      // depending on how TrustTunnel expects the server name/ID to be passed.
      vpnRepo.connect(serverName: 'server'); 
    });

    runApp(
      DependencyScope(
        dependenciesFactory: initializationResult.dependenciesFactory,
        repositoryFactory: initializationResult.repositoryFactory,
        child: ServersScope(
          child: RoutingScope(
            child: ExcludedRoutesScope(
              child: VpnScope(
                vpnRepository: initializationResult.repositoryFactory.vpnRepository,
                initialState: initializationResult.initialVpnState,
                child: const VpnUpdateManager(
                  child: DeepLinkScope(
                    child: App(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  },
  (e, st) {
    log(
      'Error catched in main thread',
      error: e,
      stackTrace: st,
    );
  },
);
