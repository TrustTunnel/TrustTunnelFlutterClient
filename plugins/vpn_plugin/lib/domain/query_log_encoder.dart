import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:vpn_plugin/models/connection_protocol.dart';
import 'package:vpn_plugin/models/query_log_action.dart';
import 'package:vpn_plugin/models/query_log_row.dart';

/// Converts JSON map data into structured [QueryLogRow] objects.
///
/// Used to decode network traffic logs from the VPN implementation into
/// Dart objects for display.
@immutable
final class QueryLogEncoder extends Converter<Map<String, Object?>, QueryLogRow> {
  static const String _actionKey = 'action';
  static const String _domainKey = 'domain';
  static const String _sourceKey = 'src';
  static const String _destinationKey = 'dst';
  static const String _protocolKey = 'proto';
  static const String _timeStampKey = 'date';

  /// Converts a raw JSON map into a structured [QueryLogRow] object.
  ///
  /// Parses and validates all required fields from the input map.
  /// Throws [FormatException] if required data is missing or invalid.
  @override
  QueryLogRow convert(Map<String, Object?> input) {
    final action = _parseAction(input);
    final protocol = _parseProtocol(input);
    final source = _parseRequiredString(input, _sourceKey);
    final destination = _parseNullableString(input, _destinationKey);
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

  /// Parses a timestamp from the input map.
  ///
  /// Throws [FormatException] if the timestamp cannot be parsed.
  DateTime _parseTimeStamp(Map<String, Object?> input, String key) {
    final rawSource = input[key];
    final parsingResult = DateTime.tryParse(rawSource.toString());

    if (parsingResult == null) {
      throw FormatException(
        'Cannot parse $input into source. Expected $rawSource of type ${rawSource.runtimeType} to be DateTime?',
      );
    }

    return parsingResult;
  }

  /// Parses an optional string value from the input map.
  ///
  /// Throws [FormatException] if the value is present but not a string.
  String? _parseNullableString(Map<String, Object?> input, String key) {
    final rawSource = input[key];

    if (rawSource is! String?) {
      throw FormatException(
        'Cannot parse $input into source. Expected $rawSource of type ${rawSource.runtimeType} to be String?',
      );
    }

    return rawSource;
  }

  /// Parses a required string value from the input map.
  ///
  /// Throws [FormatException] if the value is missing or not a string.
  String _parseRequiredString(Map<String, Object?> input, String key) {
    final rawSource = input[key];

    if (rawSource == null) {
      throw FormatException('Cannot parse $input into source. Expected $key to be not null');
    }

    return rawSource.toString().trim();
  }

  /// Parses the connection protocol from the input map.
  ///
  /// Throws [FormatException] if the protocol value is invalid.
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

  /// Parses the query log action from the input map.
  ///
  /// Throws [FormatException] if the action value is invalid.
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