import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:vpn_plugin/models/connection_protocol.dart';
import 'package:vpn_plugin/models/query_log_action.dart';
import 'package:vpn_plugin/models/query_log_row.dart';

class QueryLogEncoder extends Converter<Map<String, Object?>, QueryLogRow> {
  static const String _actionKey = 'action';
  static const String _domainKey = 'domain';
  static const String _sourceKey = 'src';
  static const String _destinationKey = 'dst';
  static const String _protocolKey = 'proto';
  static const String _timeStampKey = 'date';

  @override
  QueryLogRow convert(Map<String, Object?> input) {
    final action = _parseAction(input);
    final protocol = _parseProtocol(input);
    final source = _parseRequiredString(input, _sourceKey);
    final destination = _parseRequiredString(input, _destinationKey);
    final domain = _parseNullableString(input, _domainKey);
    final timeStamp = _parseTimeStamp(input, _timeStampKey);

    return QueryLogRow(
      action: action,
      protocol: protocol,
      source: source,
      destination: destination,
      domain: domain,
      stamp: timeStamp,
    );
  }

  DateTime _parseTimeStamp(Map<String, Object?> input, String key) {
    final rawSource = input[key];
    final parsingResult = DateTime.tryParse(rawSource.toString());

    if (parsingResult == null) {
      throw FormatException(
        'Cannot pase $input into source. Expected $rawSource of type ${rawSource.runtimeType} to be DateTime?',
      );
    }

    return parsingResult;
  }

  String? _parseNullableString(Map<String, Object?> input, String key) {
    final rawSource = input[key];

    if (rawSource is! String?) {
      throw FormatException(
        'Cannot pase $input into source. Expected $rawSource of type ${rawSource.runtimeType} to be String?',
      );
    }

    return rawSource;
  }

  String _parseRequiredString(Map<String, Object?> input, String key) {
    final rawSource = input[key];

    if (rawSource == null) {
      throw FormatException('Cannot pase $input into source. Expected $_sourceKey to be not null');
    }

    return rawSource.toString().trim();
  }

  ConnectionProtocol _parseProtocol(Map<String, Object?> input) {
    final rawProtocol = (input[_protocolKey]).toString().toLowerCase().trim();

    final protocol = ConnectionProtocol.values.firstWhereOrNull((e) => e.value.toLowerCase() == rawProtocol);

    if (protocol == null) {
      throw FormatException(
        'Cannot parse $rawProtocol into protocol. Expected one of ${ConnectionProtocol.values.map((e) => e.name).toList()}',
      );
    }
    return protocol;
  }

  QueryLogAction _parseAction(Map<String, Object?> input) {
    final rawAction = (input[_actionKey]).toString().toLowerCase().trim();

    final action = QueryLogAction.values.firstWhereOrNull((e) => e.value.toLowerCase() == rawAction);

    if (action == null) {
      throw FormatException(
        'Cannot parse $rawAction into action. Expected one of ${QueryLogAction.values.map((e) => e.value).toList()}',
      );
    }
    return action;
  }
}
