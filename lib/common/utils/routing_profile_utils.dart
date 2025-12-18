import 'package:trusttunnel/data/model/routing_profile.dart';

abstract class RoutingProfileUtils {
  static const defaultRoutingProfileId = 0;

  static bool isDefaultRoutingProfile({required RoutingProfile profile}) => profile.id == defaultRoutingProfileId;
}
