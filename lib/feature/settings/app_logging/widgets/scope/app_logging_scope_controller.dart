import 'package:flutter/foundation.dart';
import 'package:trusttunnel/common/error/model/presentation_exception.dart';
import 'package:trusttunnel/common/logging/enum/logging_level.dart';
import 'package:trusttunnel/common/logging/enum/logging_security_type.dart';

abstract class AppLoggingScopeController implements Listenable {
  abstract final PresentationException? error;

  abstract final bool loading;

  abstract final LoggingLevel loggingLevel;

  abstract final LoggingSecurityType securityType;

  abstract final void Function({
    required LoggingLevel level,
  })
  updateLoggingLevel;

  abstract final void Function({
    required LoggingSecurityType securityType,
  })
  updateSecurityType;
}
