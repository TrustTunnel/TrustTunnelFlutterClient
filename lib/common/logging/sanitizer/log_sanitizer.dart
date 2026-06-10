import 'package:trusttunnel/common/logging/enum/logging_security_type.dart';
import 'package:trusttunnel/common/logging/sanitizer/trust_tunnel_sensitive_data_sanitizer.dart';

class LogSanitizer {
  final TrustTunnelSensitiveDataSanitizer _sensitiveDataSanitizer;

  const LogSanitizer({
    TrustTunnelSensitiveDataSanitizer sensitiveDataSanitizer = const TrustTunnelSensitiveDataSanitizer(),
  }) : _sensitiveDataSanitizer = sensitiveDataSanitizer;

  String sanitizeText(String value, LoggingSecurityType securityType) =>
      _sensitiveDataSanitizer.sanitizeText(value, securityType);

  Object? sanitizePayload(Object? value, LoggingSecurityType securityType) =>
      _sensitiveDataSanitizer.sanitizePayload(value, securityType);

  Object? sanitizeError(Object? value, LoggingSecurityType securityType) {
    if (value == null) {
      return null;
    }

    return sanitizeText(value.toString(), securityType);
  }

  StackTrace? sanitizeStackTrace(StackTrace? stackTrace, LoggingSecurityType securityType) {
    if (stackTrace == null) {
      return null;
    }

    return StackTrace.fromString(sanitizeText(stackTrace.toString(), securityType));
  }

  List<String>? sanitizeTags(List<String>? tags, LoggingSecurityType securityType) =>
      tags?.map((tag) => sanitizeText(tag, securityType)).toList();
}
