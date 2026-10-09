import 'package:trusttunnel/common/error/model/presentation_exception.dart';
import 'package:trusttunnel/common/logging/enum/logging_level.dart';
import 'package:trusttunnel/common/logging/enum/logging_security_type.dart';
import 'package:trusttunnel/data/model/server.dart';
import 'package:trusttunnel/data/model/vpn_state.dart';

/// State used to build the tray and report scope errors.
final class TrayMenuState {
  final VpnState vpnState;
  final List<Server> servers;
  final Server? selectedServer;
  final LoggingLevel loggingLevel;
  final LoggingSecurityType loggingSecurityType;
  final PresentationException? serverError;
  final PresentationException? loggingError;

  const TrayMenuState({
    required this.vpnState,
    required this.servers,
    required this.selectedServer,
    required this.loggingLevel,
    required this.loggingSecurityType,
    required this.serverError,
    required this.loggingError,
  });
}
