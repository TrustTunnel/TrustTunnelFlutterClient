import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:vpn/data/model/routing_mode.dart';

part 'routing_profile.freezed.dart';

@freezed
class RoutingProfile with _$RoutingProfile {
  const RoutingProfile._();

  const factory RoutingProfile({
    required int id,
    required String name,
    required RoutingMode defaultMode,
    required List<String> bypassRules,
    required List<String> vpnRules,
  }) = _RoutingProfile;
}
