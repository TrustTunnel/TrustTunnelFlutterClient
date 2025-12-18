import 'package:trusttunnel/data/model/raw/add_routing_profile_request.dart';
import 'package:trusttunnel/data/model/routing_mode.dart';
import 'package:trusttunnel/data/model/routing_profile.dart';

/// {@template routing_data_source}
/// Persistence interface for routing profiles and their rules.
///
/// A routing profile typically contains:
/// - a human-readable name,
/// - a default routing mode ([RoutingMode]),
/// - two rule sets (e.g. "bypass" and "vpn") stored as plain strings.
///
/// This data source is responsible only for storing and retrieving profile data.
/// Any validation or higher-level business rules should be implemented above
/// this layer.
/// {@endtemplate}
abstract class RoutingDataSource {
  /// {@template routing_data_source_add_new_profile}
  /// Creates a new routing profile and persists its rules.
  ///
  /// Implementations should store:
  /// - profile metadata (name + default mode),
  /// - both bypass and VPN rules (as separate rows, if applicable).
  ///
  /// Returns a fully populated [RoutingProfile] including the database-generated
  /// identifier and the persisted rule lists.
  /// {@endtemplate}
  Future<RoutingProfile> addNewProfile(AddRoutingProfileRequest request);

  /// {@template routing_data_source_get_profile_by_id}
  /// Loads a routing profile by its identifier.
  ///
  /// Implementations may throw if no profile exists for the given [id].
  /// {@endtemplate}
  Future<RoutingProfile> getProfileById({required int id});

  /// {@template routing_data_source_get_all_profiles}
  /// Loads all routing profiles stored in persistence.
  ///
  /// Returns an empty list if no profiles exist.
  /// {@endtemplate}
  Future<List<RoutingProfile>> getAllProfiles();

  /// {@template routing_data_source_set_default_mode}
  /// Updates the default routing mode of a profile.
  /// {@endtemplate}
  Future<void> setDefaultRoutingMode({required int id, required RoutingMode mode});

  /// {@template routing_data_source_set_profile_name}
  /// Updates the user-visible name of a profile.
  /// {@endtemplate}
  Future<void> setProfileName({required int id, required String name});

  /// {@template routing_data_source_set_rules}
  /// Replaces the rule set for a specific [mode] in a profile.
  ///
  /// The implementation is expected to remove existing rules for the given
  /// `[id, mode]` pair and then insert the provided [rules].
  /// {@endtemplate}
  Future<void> setRules({required int id, required RoutingMode mode, required List<String> rules});

  /// {@template routing_data_source_remove_all_rules}
  /// Removes all rules for the specified profile.
  ///
  /// This does not necessarily delete the profile itself.
  /// {@endtemplate}
  Future<void> removeAllRules({required int id});

  /// {@template routing_data_source_delete_profile}
  /// Deletes a routing profile.
  ///
  /// Implementations may need to handle foreign-key-like relationships where
  /// other entities refer to this profile (e.g. servers bound to a profile).
  /// {@endtemplate}
  Future<void> deleteProfile({required int id});
}
