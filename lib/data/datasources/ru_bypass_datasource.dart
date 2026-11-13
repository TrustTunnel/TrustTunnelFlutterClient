import 'package:trusttunnel/data/datasources/ru_bypass_update_result.dart';

/// {@template ru_bypass_data_source}
/// Storage and updater for the Runet bypass data.
///
/// Keeps:
/// - the enabled flag and the last update timestamp in [SharedPreferences];
/// - the downloaded RU CIDR list in a plain text file in the application
///   documents directory (one CIDR per line).
/// {@endtemplate}
abstract class RuBypassDataSource {
  /// Whether Runet bypass is enabled.
  Future<bool> isEnabled();

  /// Updates the enabled flag.
  Future<void> setEnabled(bool enabled);

  /// Returns the stored RU CIDR list (may be empty if never downloaded).
  Future<List<String>> getCidrList();

  /// Returns the timestamp of the last successful CIDR list update
  /// (Unix milliseconds), or `null` if never updated.
  Future<DateTime?> getLastUpdateDate();

  /// Downloads the RU CIDR list and replaces the stored copy.
  ///
  /// Returns the update result with the number of stored entries.
  Future<RuBypassUpdateResult> updateCidrList();

  /// Whether a CIDR list has been downloaded at least once.
  Future<bool> hasCidrList();
}
