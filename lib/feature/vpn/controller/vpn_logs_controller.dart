import 'package:flutter/foundation.dart';
import 'package:trusttunnel/data/model/vpn_log.dart';
import 'package:trusttunnel/feature/vpn/models/log_controller.dart';

final class VpnLogsController extends ValueNotifier<List<VpnLog>> implements LogController {
  final int _logLimit;

  VpnLogsController({this._logLimit = 500}) : super(const []);

  @override
  List<VpnLog> get logs => value;

  void onLogCollected(VpnLog log) {
    final retained = logs.length >= _logLimit ? logs.skip(logs.length - _logLimit + 1) : logs;

    value = List.unmodifiable([...retained, log]);
  }
}
