import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';
import 'package:trusttunnel/data/model/vpn_log_action.dart';
import 'package:trusttunnel/data/model/vpn_log_protocol.dart';

/// {@template vpn_log}
/// A single VPN log entry produced by the backend.
///
/// `VpnLog` is an immutable data model intended for:
/// - diagnostics,
/// - UI display (connection history / per-request decisions),
/// - exporting or telemetry (if your app supports it).
///
/// ## Field semantics
/// - [action] describes how the engine handled the traffic.
/// - [protocol] indicates the transport protocol.
/// - [timeStamp] is the moment the backend recorded the entry.
/// - [source] and [destination] are backend-formatted endpoint identifiers
///   (commonly `ip:port`).
/// - [domain] is optional and may be absent when the backend cannot associate
///   a domain name with the destination.
///
/// Instances are immutable and use value-based equality.
/// {@endtemplate}
@immutable
class VpnLog {
  /// Action taken by the VPN engine for this entry.
  final VpnLogAction action;

  /// Transport protocol observed for the connection.
  final VpnLogProtocol protocol;

  /// Timestamp when the backend recorded this log entry.
  final DateTime timeStamp;

  /// Source endpoint identifier (e.g. `ip:port`).
  final String source;

  /// Destination endpoint identifier (e.g. `ip:port`).
  final String? destination;

  /// Optional domain name associated with the destination.
  final String? domain;

  /// {@macro vpn_log}
  const VpnLog({
    required this.action,
    required this.protocol,
    required this.timeStamp,
    required this.source,
    required this.destination,
    this.domain,
  });

  @override
  int get hashCode => Object.hash(
    action,
    protocol,
    timeStamp,
    source,
    destination,
    domain,
  );

  @override
  String toString() =>
      'VpnLog('
      'action: $action, '
      'protocol: $protocol, '
      'timeStamp: $timeStamp, '
      'source: $source, '
      'destination: $destination, '
      'domain: $domain'
      ')';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is VpnLog &&
        other.action == action &&
        other.protocol == protocol &&
        other.timeStamp == timeStamp &&
        other.source == source &&
        other.destination == destination &&
        other.domain == domain;
  }

  /// Creates a copy of this log entry with the given fields replaced.
  ///
  /// Fields that are not provided retain their original values.
  VpnLog copyWith({
    VpnLogAction? action,
    VpnLogProtocol? protocol,
    DateTime? timeStamp,
    String? source,
    String? destination,
    String? domain,
  }) => VpnLog(
    action: action ?? this.action,
    protocol: protocol ?? this.protocol,
    timeStamp: timeStamp ?? this.timeStamp,
    source: source ?? this.source,
    destination: destination ?? this.destination,
    domain: domain ?? this.domain,
  );
}
