import 'package:trusttunnel/common/logging/enum/logging_security_type.dart';
import 'package:trusttunnel/common/logging/sanitizer/trust_tunnel_sensitive_data_sanitizer.dart';

class LogSanitizer {
  final TrustTunnelSensitiveDataSanitizer _sensitiveDataSanitizer;

  final LoggingSecurityType _securityType;

  const LogSanitizer({
    TrustTunnelSensitiveDataSanitizer sensitiveDataSanitizer = const TrustTunnelSensitiveDataSanitizer(),
    LoggingSecurityType securityType = LoggingSecurityType.stripped,
  }) : _securityType = securityType,
       _sensitiveDataSanitizer = sensitiveDataSanitizer;

  T? sanitize<T extends Object>(T? value) => _sensitiveDataSanitizer.sanitizePayload(value, _securityType);

  Object? sanitizeError(Object? value) {
    if (value == null) {
      return null;
    }

    return sanitize(value.toString());
  }

  StackTrace? sanitizeStackTrace(StackTrace? stackTrace) {
    if (stackTrace == null) {
      return null;
    }

    return StackTrace.fromString(sanitize(stackTrace.toString()) ?? '');
  }
}
