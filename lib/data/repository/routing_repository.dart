import 'dart:async';

import 'package:trusttunnel/data/datasources/routing_datasource.dart';
import 'package:trusttunnel/data/model/raw/add_routing_profile_request.dart';
import 'package:trusttunnel/data/model/routing_mode.dart';
import 'package:trusttunnel/data/model/routing_profile.dart';

abstract class RoutingRepository {
  Future<RoutingProfile> addNewProfile(AddRoutingProfileRequest request);

  Future<List<RoutingProfile>> getAllProfiles();

  Future<void> setDefaultRoutingMode({required int id, required RoutingMode mode});

  Future<void> setProfileName({required int id, required String name});

  Future<void> setRules({required int id, required RoutingMode mode, required List<String> rules});

  Future<void> removeAllRules({required int id});

  Future<RoutingProfile?> getProfileById({required int id});

  Future<void> deleteProfile({required int id});
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
  Future<RoutingProfile> addNewProfile(AddRoutingProfileRequest request) async {
    final profile = await _routingDataSource.addNewProfile(request);

    return profile;
  }

  @override
  Future<void> setDefaultRoutingMode({required int id, required RoutingMode mode}) =>
      _routingDataSource.setDefaultRoutingMode(id: id, mode: mode);

  @override
  Future<void> setProfileName({required int id, required String name}) =>
      _routingDataSource.setProfileName(id: id, name: name);

  @override
  Future<void> setRules({required int id, required RoutingMode mode, required List<String> rules}) async {
    await _routingDataSource.setRules(id: id, mode: mode, rules: rules);
  }

  @override
  Future<void> removeAllRules({required int id}) async {
    await _routingDataSource.removeAllRules(id: id);
  }

  @override
  Future<RoutingProfile?> getProfileById({required int id}) => _routingDataSource.getProfileById(id: id);

  @override
  Future<void> deleteProfile({required int id}) => _routingDataSource.deleteProfile(id: id);
}
