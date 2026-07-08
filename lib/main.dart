import 'dart:async';

import 'package:adguard_logger/adguard_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Router;
import 'package:trusttunnel/common/logging/app_logger.dart';
import 'package:trusttunnel/common/logging/extensions/db_logger_extension.dart';
import 'package:trusttunnel/common/logging/extensions/global_error_logger_extension.dart';
import 'package:trusttunnel/common/logging/extensions/vpn_logger_extension.dart';
import 'package:trusttunnel/di/model/initialization_helper.dart';
import 'package:trusttunnel/di/widgets/dependency_scope.dart';
import 'package:trusttunnel/feature/app/app.dart';
import 'package:trusttunnel/feature/deep_link/deep_link_scope.dart';
import 'package:trusttunnel/feature/routing/routing/widgets/scope/routing_scope.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/scope/excluded_routes_scope.dart';
import 'package:trusttunnel/feature/vpn/widgets/vpn_scope.dart';
import 'package:trusttunnel/feature/vpn/widgets/vpn_update_manager.dart';

Future<void> main() async {
  final logger = AppLogger(
    extensions: [
      GlobalErrorLoggerExtension(),
      VpnLoggerExtension(),
      DBLoggerExtension(),
    ],
  );

  void dispatchError(Object error, StackTrace? stackTrace) =>
      logger.extension<GlobalErrorLoggerExtension>()?.onUncaughtError(error, stackTrace);

  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      _applyGlobalErrorHandling(dispatchError);

      final initializationHelper = await const InitializationHelperIo().init();

      runApp(
        DependencyScope(
          dependenciesFactory: initializationHelper.dependenciesFactory,
          repositoryFactory: initializationHelper.repositoryFactory,
          child: ServersScope(
            child: RoutingScope(
              child: ExcludedRoutesScope(
                child: VpnScope(
                  vpnRepository: initializationHelper.repositoryFactory.vpnRepository,
                  initialState: initializationHelper.initialVpnState,
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
    zoneValues: {
      Logger.loggerKey: logger,
    },
    dispatchError,
  );
}

void _applyGlobalErrorHandling(void Function(Object error, StackTrace? stackTrace) handleError) {
  FlutterError.onError = (details) {
    if (!details.silent) {
      handleError(details.exception, details.stack);
    }
    if (kDebugMode) {
      FlutterError.presentError(details);
    }
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    handleError(error, stackTrace);

    return true;
  };
}
