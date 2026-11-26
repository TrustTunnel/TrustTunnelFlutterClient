import 'package:trusttunnel/common/error/model/enum/presentation_field_exception_code.dart';
import 'package:trusttunnel/common/error/model/enum/presentation_field_name.dart';
import 'package:trusttunnel/common/error/model/presentation_field.dart';

abstract class RoutingService {
  /// Validates [name] against the display names of the other profiles.
  static List<PresentationField> validateRoutingProfileName(Iterable<String> otherNames, String name) {
    final profileName = _validateProfileName(name, otherNames);
    if (profileName != null) {
      return [profileName];
    }

    return [];
  }

  static PresentationField? _validateProfileName(String name, Iterable<String> otherNames) {
    final fieldName = PresentationFieldName.profileName;
    final normalizedName = name.trim().toLowerCase();
    if (normalizedName.isEmpty) {
      return _getRequiredField(fieldName);
    }
    if (otherNames.any((otherName) => otherName.trim().toLowerCase() == normalizedName)) {
      return _getAlreadyExistsField(fieldName);
    }

    return null;
  }

  static PresentationField _getRequiredField(PresentationFieldName fieldName) => PresentationField(
    code: PresentationFieldExceptionCode.fieldRequired,
    fieldName: fieldName,
  );

  static PresentationField _getAlreadyExistsField(PresentationFieldName fieldName) => PresentationField(
    code: PresentationFieldExceptionCode.alreadyExists,
    fieldName: fieldName,
  );
}
