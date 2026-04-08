import 'package:flutter/foundation.dart';
import 'package:vpn_plugin/models/connection_protocol.dart';
import 'package:vpn_plugin/models/query_log_action.dart';

/// {@template query_log_row}
/// A single structured log entry describing how a connection was handled.
///
/// [QueryLogRow] is a data model intended for diagnostics and UI presentation.
/// It captures:
/// - what action the engine took ([action]),
/// - the transport protocol ([protocol]),
/// - the traffic endpoints ([source] and [destination]),
/// - an optional resolved [domain],
/// - and the timestamp of the event ([stamp]).
/// {@endtemplate}
@immutable
class QueryLogRow {
  /// {@template query_log_row_action}
  /// The action the engine took for this connection.
  /// {@endtemplate}
  final QueryLogAction action;

  /// {@template query_log_row_protocol}
  /// Transport protocol used by the connection.
  /// {@endtemplate}
  final ConnectionProtocol protocol;

  /// {@template query_log_row_source}
  /// Source address of the connection as reported by the backend.
  /// {@endtemplate}
  final String source;

  /// {@template query_log_row_destination}
  /// Destination address of the connection as reported by the backend.
  ///
  /// May be `null` if the backend did not provide a destination.
  /// {@endtemplate}
  final String? destination;

  /// {@template query_log_row_domain}
  /// Optional domain name associated with the destination.
  ///
  /// May be `null` if the backend did not provide a domain.
  /// {@endtemplate}
  final String? domain;

  /// {@template query_log_row_stamp}
  /// Timestamp of when the event was recorded.
  /// {@endtemplate}
  final DateTime stamp;

  /// {@macro query_log_row}
  const QueryLogRow({
    required this.action,
    required this.source,
    required this.destination,
    required this.protocol,
    required this.stamp,
    this.domain,
  });

  @override
  String toString() =>
      'QueryLogRow(action: $action, protocol: $protocol, source: $source, destination: $destination, domain: $domain)';

  @override
  int get hashCode => Object.hash(
    action,
    protocol,
    source,
    destination,
    domain,
    stamp,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueryLogRow &&
          runtimeType == other.runtimeType &&
          action == other.action &&
          protocol == other.protocol &&
          source == other.source &&
          destination == other.destination &&
          domain == other.domain &&
          stamp == other.stamp;
}
