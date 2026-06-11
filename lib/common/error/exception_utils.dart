import 'package:flutter/services.dart';
import 'package:trusttunnel/common/error/model/enum/presentation_exception_code.dart';
import 'package:trusttunnel/common/error/model/enum/presentation_field_exception_code.dart';
import 'package:trusttunnel/common/error/model/enum/presentation_field_name.dart';
import 'package:trusttunnel/common/error/model/presentation_code_exception.dart';
import 'package:trusttunnel/common/error/model/presentation_exception.dart';
import 'package:trusttunnel/common/error/model/presentation_field.dart';
import 'package:trusttunnel/common/error/model/presentation_field_exception.dart';
import 'package:trusttunnel/common/localization/generated/l10n.dart';
import 'package:vpn_plugin/platform_api.g.dart';

abstract class ExceptionUtils {
  static String getBaseExceptionString(PresentationExceptionCode code, AppLocalizations ln) => switch (code) {
    PresentationExceptionCode.unknown => ln.unknownError,
    PresentationExceptionCode.notFound => throw UnimplementedError('Text for not found error is not implemented'),
  };

  static String getFieldExceptionString(PresentationField field, AppLocalizations ln) => switch (field.code) {
    PresentationFieldExceptionCode.alreadyExists
        when (field.fieldName == PresentationFieldName.serverName ||
            field.fieldName == PresentationFieldName.profileName) =>
      ln.nameAlreadyExistError,
    PresentationFieldExceptionCode.fieldWrongValue when field.fieldName == PresentationFieldName.ipAddress =>
      ln.ipAddressWrongFieldError,
    PresentationFieldExceptionCode.fieldWrongValue when field.fieldName == PresentationFieldName.domain =>
      ln.domainWrongFieldError,
    PresentationFieldExceptionCode.fieldWrongValue when field.fieldName == PresentationFieldName.sni =>
      ln.customSniWrongFieldError,
    PresentationFieldExceptionCode.fieldWrongValue when field.fieldName == PresentationFieldName.dnsServers =>
      ln.dnsServersWrongFieldError,
    PresentationFieldExceptionCode.fieldWrongValue when field.fieldName == PresentationFieldName.url =>
      ln.urlWrongFieldError,
    PresentationFieldExceptionCode.fieldWrongValue when field.fieldName == PresentationFieldName.clientRandom =>
      ln.tlsWrongFieldError,
    PresentationFieldExceptionCode.fieldWrongValue when field.fieldName == PresentationFieldName.clientRandomMask =>
      ln.tlsWrongMaskError,
    PresentationFieldExceptionCode.fieldWrongValue when field.fieldName == PresentationFieldName.clientRandomValue =>
      ln.tlsWrongValueError,
    PresentationFieldExceptionCode.fieldRequired
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
    PresentationFieldExceptionCode.outOfBounds when field.fieldName == PresentationFieldName.clientRandom =>
      ln.tlsOutOfBoundsError,
    _ => throw Exception('Localization missed: code = ${field.code} fieldName = ${field.fieldName}'),
  };

  static PresentationExceptionCode toPresentationExceptionCode(PlatformErrorCode errorType) => switch (errorType) {
    PlatformErrorCode.unknown => PresentationExceptionCode.unknown,
  };

  static PresentationFieldExceptionCode toPresentationFieldExceptionCode(PlatformFieldErrorCode errorType) =>
      switch (errorType) {
        PlatformFieldErrorCode.fieldWrongValue => PresentationFieldExceptionCode.fieldWrongValue,
        PlatformFieldErrorCode.alreadyExists => PresentationFieldExceptionCode.alreadyExists,
      };

  static PresentationFieldName toPresentationFieldName(PlatformFieldName fieldName) => switch (fieldName) {
    PlatformFieldName.serverName => PresentationFieldName.serverName,
    PlatformFieldName.dnsServers => PresentationFieldName.dnsServers,
    PlatformFieldName.domain => PresentationFieldName.domain,
    PlatformFieldName.ipAddress => PresentationFieldName.ipAddress,
  };

  static PresentationException toPresentationException({required Object? exception}) {
    if (exception is! PlatformException || exception.details is! PlatformErrorResponse) {
      return const PresentationCodeException(code: PresentationExceptionCode.unknown);
    }

    final PlatformErrorResponse errorResponse = exception.details as PlatformErrorResponse;

    if (errorResponse.fieldErrors == null) {
      return PresentationCodeException(code: toPresentationExceptionCode(errorResponse.code!));
    }

    return PresentationFieldException(
      fields: errorResponse.fieldErrors!
          .cast<PlatformFieldError>()
          .map(
            (platformFieldError) => PresentationField(
              code: toPresentationFieldExceptionCode(platformFieldError.code),
              fieldName: toPresentationFieldName(platformFieldError.fieldName),
            ),
          )
          .toList(),
    );
  }
}
