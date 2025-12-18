import 'package:trusttunnel/common/error/model/enum/presentation_field_error_code.dart';
import 'package:trusttunnel/common/error/model/enum/presentation_field_name.dart';
import 'package:trusttunnel/common/error/model/presentation_field.dart';
import 'package:trusttunnel/data/model/routing_profile.dart';

abstract class RoutingService {
  static List<PresentationField> validateRoutingProfileName(Set<RoutingProfile> profiles, String name) {
    final profileName = _validateProfileName(name, profiles.map((e) => e.name).toSet());
    if (profileName != null) {
      return [profileName];
    }

    return [];
  }

  static PresentationField? _validateProfileName(String serverName, Set<String> otherServerNames) {
    final fieldName = PresentationFieldName.profileName;
    if (serverName.trim().isEmpty) {
      return _getRequiredField(fieldName);
    }
    if (otherServerNames.map((e) => e.trim().toLowerCase()).contains(serverName.trim().toLowerCase())) {
      return _getAlreadyExistsField(fieldName);
    }

    return null;
  }

  static PresentationField _getRequiredField(PresentationFieldName fieldName) => PresentationField(
    code: PresentationFieldErrorCode.fieldRequired,
    fieldName: fieldName,
  );

  static PresentationField _getAlreadyExistsField(PresentationFieldName fieldName) => PresentationField(
    code: PresentationFieldErrorCode.alreadyExists,
    fieldName: fieldName,
  );
}
