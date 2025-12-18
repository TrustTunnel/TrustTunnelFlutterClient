import 'package:flutter/services.dart';
import 'package:trusttunnel/common/error/model/enum/presentation_error_code.dart';
import 'package:trusttunnel/common/error/model/enum/presentation_field_error_code.dart';
import 'package:trusttunnel/common/error/model/enum/presentation_field_name.dart';
import 'package:trusttunnel/common/error/model/presentation_base_error.dart';
import 'package:trusttunnel/common/error/model/presentation_error.dart';
import 'package:trusttunnel/common/error/model/presentation_field.dart';
import 'package:trusttunnel/common/error/model/presentation_field_error.dart';
import 'package:trusttunnel/common/localization/generated/l10n.dart';
import 'package:vpn_plugin/platform_api.g.dart';

abstract class ErrorUtils {
  static String getBaseErrorString(PresentationErrorCode code, AppLocalizations ln) => switch (code) {
    PresentationErrorCode.unknown => ln.unknownError,
    PresentationErrorCode.notFound => throw UnimplementedError('Text for not found error is not implemented'),
  };

  static String getFieldErrorString(PresentationField field, AppLocalizations ln) => switch (field.code) {
    PresentationFieldErrorCode.alreadyExists
        when (field.fieldName == PresentationFieldName.serverName ||
            field.fieldName == PresentationFieldName.profileName) =>
      ln.nameAlreadyExistError,
    PresentationFieldErrorCode.fieldWrongValue when field.fieldName == PresentationFieldName.ipAddress =>
      ln.ipAddressWrongFieldError,
    PresentationFieldErrorCode.fieldWrongValue when field.fieldName == PresentationFieldName.domain =>
      ln.domainWrongFieldError,
    PresentationFieldErrorCode.fieldWrongValue when field.fieldName == PresentationFieldName.dnsServers =>
      ln.dnsServersWrongFieldError,
    PresentationFieldErrorCode.fieldWrongValue when field.fieldName == PresentationFieldName.url =>
      ln.urlWrongFieldError,
    PresentationFieldErrorCode.fieldRequired
        when field.fieldName == PresentationFieldName.userName ||
            field.fieldName == PresentationFieldName.ipAddress ||
            field.fieldName == PresentationFieldName.domain ||
            field.fieldName == PresentationFieldName.dnsServers ||
            field.fieldName == PresentationFieldName.password ||
            field.fieldName == PresentationFieldName.serverName ||
            field.fieldName == PresentationFieldName.profileName ||
            field.fieldName == PresentationFieldName.rule ||
            field.fieldName == PresentationFieldName.url =>
      ln.pleaseFillField,
    _ => throw Exception('Localization missed: code = ${field.code} fieldName = ${field.fieldName}'),
  };

  static PresentationErrorCode toPresentationErrorCode(PlatformErrorCode errorType) => switch (errorType) {
    PlatformErrorCode.unknown => PresentationErrorCode.unknown,
  };

  static PresentationFieldErrorCode toPresentationFieldErrorCode(PlatformFieldErrorCode errorType) =>
      switch (errorType) {
        PlatformFieldErrorCode.fieldWrongValue => PresentationFieldErrorCode.fieldWrongValue,
        PlatformFieldErrorCode.alreadyExists => PresentationFieldErrorCode.alreadyExists,
      };

  static PresentationFieldName toPresentationFieldName(PlatformFieldName fieldName) => switch (fieldName) {
    PlatformFieldName.serverName => PresentationFieldName.serverName,
    PlatformFieldName.dnsServers => PresentationFieldName.dnsServers,
    PlatformFieldName.domain => PresentationFieldName.domain,
    PlatformFieldName.ipAddress => PresentationFieldName.ipAddress,
  };

  static PresentationError toPresentationError({required Object? exception}) {
    if (exception is! PlatformException || exception.details is! PlatformErrorResponse) {
      return PresentationBaseError(code: PresentationErrorCode.unknown);
    }

    final PlatformErrorResponse errorResponse = exception.details as PlatformErrorResponse;

    if (errorResponse.fieldErrors == null) {
      return PresentationBaseError(code: toPresentationErrorCode(errorResponse.code!));
    }

    return PresentationFieldError(
      fields: errorResponse.fieldErrors!
          .cast<PlatformFieldError>()
          .map(
            (platformFieldError) => PresentationField(
              code: toPresentationFieldErrorCode(platformFieldError.code),
              fieldName: toPresentationFieldName(platformFieldError.fieldName),
            ),
          )
          .toList(),
    );
  }
}
