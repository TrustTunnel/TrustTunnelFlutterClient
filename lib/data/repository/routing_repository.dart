import 'dart:async';

import 'package:trusttunnel/data/datasources/routing_datasource.dart';
import 'package:trusttunnel/data/model/routing_mode.dart';
import 'package:trusttunnel/data/model/routing_profile.dart';
import 'package:trusttunnel/data/model/routing_profile_data.dart';

abstract class RoutingRepository {
  Future<RoutingProfile> addNewProfile(RoutingProfileData request);

  Future<List<RoutingProfile>> getAllProfiles();

  Future<void> setDefaultRoutingMode({required String id, required RoutingMode mode});

  Future<void> setProfileName({required String id, required String name});

  Future<void> setRules({required String id, required RoutingMode mode, required List<String> rules});

  Future<void> removeAllRules({required String id});

  Future<RoutingProfile?> getProfileById({required String id});

  Future<void> deleteProfile({required String id});
}

class RoutingRepositoryImpl implements RoutingRepository {
  final RoutingDataSource _routingDataSource;

  RoutingRepositoryImpl({
    required RoutingDataSource routingDataSource,
  }) : _routingDataSource = routingDataSource;

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
  Future<void> setProfileName({required String id, required String name}) =>
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
