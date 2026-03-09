import 'package:drift/drift.dart';
import 'package:trusttunnel/data/database/app_database.dart' as db;
import 'package:trusttunnel/data/datasources/routing_datasource.dart';
import 'package:trusttunnel/data/model/routing_mode.dart';
import 'package:trusttunnel/data/model/routing_profile.dart';
import 'package:trusttunnel/data/model/routing_profile_data.dart';
import 'package:vpn_plugin/deep_link_manager.dart';
import 'package:vpn_plugin/models/vpn_mode.dart';

/// {@template routing_data_source_impl}
/// Drift-backed implementation of [RoutingDataSource].
///
/// This implementation stores routing profiles and their rules in a relational
/// schema using Drift:
/// - profile metadata is stored in `routingProfiles`,
/// - individual rules are stored in `profileRules` with a `mode` discriminator.
///
/// ### Consistency notes
/// Some operations perform multiple SQL statements (insert profile, then insert
/// rules). If you require strict atomicity across these statements, consider
/// wrapping calls in a Drift transaction at a higher level.
/// {@endtemplate}
class RoutingDataSourceImpl implements RoutingDataSource {
  /// Drift _database used for persistence.
  final db.AppDatabase _database;

  final DeepLinkManager _deepLinkManager;

  /// {@macro routing_data_source_impl}
  RoutingDataSourceImpl({
    required db.AppDatabase database,
    required DeepLinkManager deepLinkManager,
  }) : _database = database,
       _deepLinkManager = deepLinkManager;

  /// {@macro routing_data_source_add_new_profile}
  @override
  Future<RoutingProfile> addNewProfile(RoutingProfileData request) async {
    final resultId = await _database.routingProfiles.insertOnConflictUpdate(
      db.RoutingProfilesCompanion.insert(
        name: request.name,
        defaultMode: request.defaultMode.value,
      ),
    );

    final bypassRules = request.bypassRules.map(
      (rule) => db.ProfileRulesCompanion.insert(
        profileId: resultId,
        mode: RoutingMode.bypass.value,
        data: rule,
      ),
    );

    final vpnRules = request.vpnRules.map(
      (rule) => db.ProfileRulesCompanion.insert(
        profileId: resultId,
        mode: RoutingMode.vpn.value,
        data: rule,
      ),
    );

    await _database.profileRules.insertAll(
      [
        ...bypassRules,
        ...vpnRules,
      ],
    );

    return RoutingProfile(
      id: resultId.toString(),
      data: RoutingProfileData(
        name: request.name,
        defaultMode: request.defaultMode,
        bypassRules: request.bypassRules,
        vpnRules: request.vpnRules,
      ),
    );
  }

  /// {@macro routing_data_source_get_all_profiles}
  ///
  /// This method loads profiles first, then loads all rules for the retrieved
  /// profile ids, and finally assembles [RoutingProfile] instances.
  @override
  Future<List<RoutingProfile>> getAllProfiles() async {
    final profiles = await _database.select(_database.routingProfiles).get();
    if (profiles.isEmpty) return [];

    final profileIds = profiles.map((p) => p.id).toSet();
    final rules = await _loadRulesOfProfiles(profileIds);

    final bypassByProfile = <int, List<String>>{};
    final vpnByProfile = <int, List<String>>{};

    for (final r in rules) {
      if (r.mode == RoutingMode.bypass.value) {
        (bypassByProfile[r.profileId] ??= <String>[]).add(r.data);
      } else if (r.mode == RoutingMode.vpn.value) {
        (vpnByProfile[r.profileId] ??= <String>[]).add(r.data);
      }
    }

    return profiles.map((p) {
      final defaultMode = RoutingMode.values.firstWhere((m) => m.value == p.defaultMode);

      return RoutingProfile(
        id: p.id.toString(),
        data: RoutingProfileData(
          name: p.name,
          defaultMode: defaultMode,
          bypassRules: bypassByProfile[p.id] ?? const [],
          vpnRules: vpnByProfile[p.id] ?? const [],
        ),
      );
    }).toList();
  }

  /// {@macro routing_data_source_set_default_mode}
  @override
  Future<void> setDefaultRoutingMode({required String id, required RoutingMode mode}) async {
    final updateStatement = _database.update(
      _database.routingProfiles,
    );
    updateStatement.where((p) => p.id.equals(int.parse(id)));
    await updateStatement.write(db.RoutingProfilesCompanion(defaultMode: Value(mode.value)));
  }

  /// {@macro routing_data_source_set_profile_name}
  @override
  Future<void> setProfileName({required String id, required String name}) async {
    final updateStatement = _database.update(
      _database.routingProfiles,
    );
    updateStatement.where((p) => p.id.equals(int.parse(id)));
    await updateStatement.write(db.RoutingProfilesCompanion(name: Value(name)));
  }

  /// {@macro routing_data_source_set_rules}
  ///
  /// Existing rules for the `[profileId, mode]` pair are deleted first, then the
  /// new list is inserted in a batch.
  @override
  Future<void> setRules({required String id, required RoutingMode mode, required List<String> rules}) async {
    await _database.profileRules.deleteWhere((p) => p.profileId.equals(int.parse(id)) & p.mode.equals(mode.value));

    return _database.batch((batch) {
      batch.insertAllOnConflictUpdate(
        _database.profileRules,
        rules.map(
          (data) => db.ProfileRulesCompanion.insert(
            profileId: int.parse(id),
            mode: mode.value,
            data: data,
          ),
        ),
      );
    });
  }

  /// {@macro routing_data_source_remove_all_rules}
  @override
  Future<void> removeAllRules({required String id}) async {
    final deleteStatement = _database.delete(
      _database.profileRules,
    );
    deleteStatement.where((p) => p.profileId.equals(int.parse(id)));
    await deleteStatement.go();
  }

  /// {@macro routing_data_source_get_profile_by_id}
  ///
  /// Throws a generic [Exception] when the profile row does not exist.
  @override
  Future<RoutingProfile> getProfileById({required String id}) async {
    final profile = await (_database.routingProfiles.select()..where((p) => p.id.equals(int.parse(id))))
        .getSingleOrNull();
    if (profile == null) throw Exception('Profile not found');

    final rules = await _loadRulesOfProfiles({int.parse(id)});

    final bypassRules = rules.where((r) => r.mode == RoutingMode.bypass.value).map((r) => r.data).toList();
    final vpnRules = rules.where((r) => r.mode == RoutingMode.vpn.value).map((r) => r.data).toList();

    return RoutingProfile(
      id: profile.id.toString(),
      data: RoutingProfileData(
        name: profile.name,
        defaultMode: RoutingMode.values.firstWhere((m) => m.value == profile.defaultMode),
        bypassRules: bypassRules,
        vpnRules: vpnRules,
      ),
    );
  }

  /// {@macro routing_data_source_delete_profile}
  ///
  /// If there are servers referencing the profile being deleted, this
  /// implementation reassigns them to another existing profile (the first one
  /// returned by the _database query) before removing the profile row.
  @override
  Future<void> deleteProfile({required String id}) async {
    final servers = await (_database.select(
      _database.servers,
    )..where((s) => s.routingProfileId.equals(int.parse(id)))).get();
    if (servers.isNotEmpty) {
      final replacedConfig =
          await (_database.select(_database.routingProfiles)
                ..where((p) => p.id.isNotValue(int.parse(id)))
                ..limit(1))
              .getSingle();

      _database.batch((batch) {
        batch.update(
          _database.servers,
          db.ServersCompanion(
            routingProfileId: Value(replacedConfig.id),
          ),
          where: (s) => s.id.isIn(servers.map((s) => s.id)),
        );
      });
    }

    final deleteStatement = _database.delete(
      _database.routingProfiles,
    );
    deleteStatement.where((p) => p.id.equals(int.parse(id)));
    await deleteStatement.go();
  }

  @override
  Future<RoutingProfileData> getProfileDataByBase64({
    required String base64,
    required String name,
  }) async {
    final config = await _deepLinkManager.getConfigurationByBase64(base64: base64);
    final vpnRules = config.vpnMode == VpnMode.general ? config.tun.includedRoutes : config.tun.excludedRoutes;
    final bypassRules = config.vpnMode == VpnMode.general ? config.tun.excludedRoutes : config.tun.includedRoutes;

    return RoutingProfileData(
      name: name,
      defaultMode: config.vpnMode == VpnMode.general ? RoutingMode.vpn : RoutingMode.bypass,
      bypassRules: bypassRules,
      vpnRules: vpnRules,
    );
  }

  /// Loads all rule rows for the given profile ids.
  ///
  /// Rules are returned in insertion order (ascending by row id).
  Future<List<db.ProfileRule>> _loadRulesOfProfiles(Set<int> profileIds) async {
    final select = _database.select(_database.profileRules)
      ..where((r) => r.profileId.isIn(profileIds))
      ..orderBy(
        [
          (r) => OrderingTerm.asc(
            r.rowId,
          ),
        ],
      );

    return select.get();
  }
}
