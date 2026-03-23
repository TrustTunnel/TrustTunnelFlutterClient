import 'package:flutter/services.dart';
import 'package:trusttunnel/common/utils/validation_utils.dart';

class RoutingSpellCheckService implements SpellCheckService {
  static final RegExp _tokenizer = RegExp(r'\S+');

  final ValueChanged<bool> onChecked;

  RoutingSpellCheckService({required this.onChecked});

  @override
  Future<List<SuggestionSpan>?> fetchSpellCheckSuggestions(
    _,
    String text,
  ) async {
    final invalidSpans = <SuggestionSpan>[];

    for (final match in _tokenizer.allMatches(text)) {
      final token = match.group(0)?.trim() ?? '';
      if (token.isEmpty || _isValidToken(token)) {
        continue;
      }

      invalidSpans.add(
        SuggestionSpan(
          TextRange(start: match.start, end: match.end),
          const [],
        ),
      );
    }

    onChecked(invalidSpans.isEmpty);

    return invalidSpans;
  }

  bool validateIp(
    String ipAddress, {
    bool includeCidr = false,
  }) {
    final value = ipAddress.trim();
    if (value.isEmpty) {
      return false;
    }

    if (includeCidr) {
      if (!ValidationUtils.validateCidr(value)) {
        return false;
      }

      final address = value.split('/').first;

      return ValidationUtils.validateIpAddress(address, allowPort: false);
    }

    return ValidationUtils.validateIpAddress(value);
  }

  bool validateDomain(String domain) =>
      ValidationUtils.tryParseDomain(
        domain,
        allowFirstLevel: true,
      ) !=
      null;

  bool _isValidToken(String value) => validateIp(value, includeCidr: value.contains('/')) || validateDomain(value);
}
