import 'package:trusttunnel/data/model/routing_profile.dart';
import 'package:trusttunnel/feature/routing/routing_details/model/routing_profile_name.dart';

abstract class RoutingProfileUtils {
  static const defaultRoutingProfileId = '0';

  static bool isDefaultRoutingProfile({required RoutingProfile profile}) => profile.id == defaultRoutingProfileId;

  /// Returns the custom name or [defaultProfileName] in the current locale.
  static String displayName({
    required RoutingProfileName name,
    required String defaultProfileName,
  }) => name.isDefault ? defaultProfileName : name.value;
}
