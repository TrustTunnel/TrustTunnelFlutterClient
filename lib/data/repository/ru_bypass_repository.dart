import 'package:trusttunnel/data/datasources/ru_bypass_datasource.dart';
import 'package:trusttunnel/data/datasources/ru_bypass_update_result.dart';
import 'package:trusttunnel/data/presets/ru_bypass_preset.dart';

/// {@template ru_bypass_state}
/// Snapshot of the Runet bypass settings.
/// {@endtemplate}
final class RuBypassSettings {
  /// Whether Runet bypass is enabled.
  final bool enabled;

  /// Timestamp of the last successful CIDR list update (or `null`).
  final DateTime? lastUpdateDate;

  /// Number of CIDR entries in the stored list.
  final int cidrCount;

  /// {@macro ru_bypass_state}
  const RuBypassSettings({
    required this.enabled,
    required this.lastUpdateDate,
    required this.cidrCount,
  });

  /// Constant list of preset domains bundled with the app.
  List<String> get domains => RuBypassPreset.domains;

  /// Stored CIDR entries are loaded separately via [RuBypassRepository.getCidrList].
  @override
  String toString() =>
      'RuBypassSettings(enabled: $enabled, lastUpdateDate: $lastUpdateDate, cidrCount: $cidrCount)';
}

/// {@template ru_bypass_repository}
/// Repository for the Runet bypass settings and exclusion lists.
/// {@endtemplate}
abstract class RuBypassRepository {
  /// Loads the current state (flag, last update, CIDR count).
  Future<RuBypassSettings> getState();

  /// Loads the stored CIDR list.
  Future<List<String>> getCidrList();

  /// Updates the enabled flag.
  Future<void> setEnabled(bool enabled);

  /// Re-downloads the RU CIDR list and returns the update result.
  Future<RuBypassUpdateResult> updateLists();
}

/// {@template ru_bypass_repository_impl}
/// Default implementation of [RuBypassRepository].
/// {@endtemplate}
class RuBypassRepositoryImpl implements RuBypassRepository {
  final RuBypassDataSource _dataSource;

  /// {@macro ru_bypass_repository_impl}
  RuBypassRepositoryImpl(this._dataSource);

  @override
  Future<RuBypassSettings> getState() async {
    final results = await Future.wait<Object?>([
      _dataSource.isEnabled(),
      _dataSource.getLastUpdateDate(),
      _dataSource.getCidrList(),
    ]);

    return RuBypassSettings(
      enabled: results[0]! as bool,
      lastUpdateDate: results[1] as DateTime?,
      cidrCount: (results[2]! as List<String>).length,
    );
  }

  @override
  Future<List<String>> getCidrList() => _dataSource.getCidrList();

  @override
  Future<void> setEnabled(bool enabled) => _dataSource.setEnabled(enabled);

  @override
  Future<RuBypassUpdateResult> updateLists() => _dataSource.updateCidrList();
}
