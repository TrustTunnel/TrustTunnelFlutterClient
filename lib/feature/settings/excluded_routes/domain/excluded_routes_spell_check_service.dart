import 'package:flutter/services.dart';
import 'package:vpn/common/utils/validation_utils.dart';

class ExcludedRoutesSpellCheckService implements SpellCheckService {
  final ValueChanged<bool> onChecked;

  ExcludedRoutesSpellCheckService({required this.onChecked});

  final _tokenizer = r'\S+';

  @override
  Future<List<SuggestionSpan>?> fetchSpellCheckSuggestions(_, String text) async {
    final invalidSpans = <SuggestionSpan>[];

    for (final m in RegExp(_tokenizer).allMatches(text)) {
      final token = m.group(0)!;

      if (_isValidToken(token.trim())) continue;

      invalidSpans.add(
        SuggestionSpan(
          TextRange(start: m.start, end: (m.end).clamp(0, m.end)),
          const [],
        ),
      );
    }

    onChecked(invalidSpans.isEmpty);

    return invalidSpans;
  }

  bool validateIp(
    String ipAddress,
  ) {
    String? modifiedAddress = ipAddress;
    final cidrValidation = ValidationUtils.validateCidr(ipAddress);

    if (!cidrValidation) {
      return false;
    }

    modifiedAddress = ipAddress.split('/').firstOrNull;

    return ValidationUtils.validateIpAddress(modifiedAddress!, allowPort: false);
  }

  bool _isValidToken(String s) => validateIp(s);
}
