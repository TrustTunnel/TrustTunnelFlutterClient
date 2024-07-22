part of 'routing_bloc.dart';

@freezed
class RoutingEvent with _$RoutingEvent {
  const factory RoutingEvent.init() = _Init;
  
  const factory RoutingEvent.selectProfile({
    required RoutingProfile routingProfile,
  }) = _SelectProfile;
}
