import 'package:trusttunnel/data/model/routing_profile.dart';

abstract class RoutingProfileUtils {
  static const defaultRoutingProfileId = '0';

  static bool isDefaultRoutingProfile({required RoutingProfile profile}) => profile.id == defaultRoutingProfileId;

  /// Returns the localized default name when the built-in profile has no stored name.
  static String displayName({
    required String? id,
    required String name,
    required String defaultProfileName,
  }) => id == defaultRoutingProfileId && name.isEmpty ? defaultProfileName : name;
}
