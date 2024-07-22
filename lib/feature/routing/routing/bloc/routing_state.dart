part of 'routing_bloc.dart';

@freezed
class RoutingState with _$RoutingState {
  const RoutingState._();

  const factory RoutingState({
    @Default([]) List<RoutingProfile> routingList,
    RoutingProfile? selectedRoutingProfile,
    RoutingProfile? defaultRoutingProfile,
  }) = _RoutingState;

  List<RoutingProfile> get allRoutingProfiles => [
        if (defaultRoutingProfile != null) defaultRoutingProfile!,
        ...routingList,
      ];
}
