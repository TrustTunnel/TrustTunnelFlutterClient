import 'dart:async';

import 'package:trusttunnel/data/datasources/routing_datasource.dart';
import 'package:trusttunnel/data/model/routing_mode.dart';
import 'package:trusttunnel/data/model/routing_profile.dart';
import 'package:trusttunnel/data/model/routing_profile_data.dart';
import 'package:trusttunnel/feature/routing/routing_details/model/routing_profile_name.dart';

abstract class RoutingRepository {
  /// Saves a new profile with a custom name.
  ///
  /// Throws [ArgumentError] if [request] uses the localized default name.
  Future<RoutingProfile> addNewProfile(RoutingProfileData request);

  Future<List<RoutingProfile>> getAllProfiles();

  Future<void> setDefaultRoutingMode({required String id, required RoutingMode mode});

  /// Stores [name]. Only the built-in profile can use the localized default name.
  Future<void> setProfileName({required String id, required RoutingProfileName name});

  Future<void> setRules({required String id, required RoutingMode mode, required List<String> rules});

  Future<void> removeAllRules({required String id});

  Future<RoutingProfile?> getProfileById({required String id});

  Future<void> deleteProfile({required String id});
}

class RoutingRepositoryImpl implements RoutingRepository {
  final RoutingDataSource _routingDataSource;

  RoutingRepositoryImpl({
    required this._routingDataSource,
  });

  @override
  Future<List<RoutingProfile>> getAllProfiles() async {
    final profiles = await _routingDataSource.getAllProfiles();

    return profiles;
  }

  @override
  Future<RoutingProfile> addNewProfile(RoutingProfileData request) async {
    final profile = await _routingDataSource.addNewProfile(request);

    return profile;
  }

  @override
  Future<void> setDefaultRoutingMode({required String id, required RoutingMode mode}) =>
      _routingDataSource.setDefaultRoutingMode(id: id, mode: mode);

  @override
  Future<void> setProfileName({required String id, required RoutingProfileName name}) =>
      _routingDataSource.setProfileName(id: id, name: name);

  @override
  Future<void> setRules({required String id, required RoutingMode mode, required List<String> rules}) async {
    await _routingDataSource.setRules(id: id, mode: mode, rules: rules);
  }

  @override
  Future<void> removeAllRules({required String id}) async {
    await _routingDataSource.removeAllRules(id: id);
  }

  @override
  Future<RoutingProfile?> getProfileById({required String id}) => _routingDataSource.getProfileById(id: id);

  @override
  Future<void> deleteProfile({required String id}) => _routingDataSource.deleteProfile(id: id);
}
