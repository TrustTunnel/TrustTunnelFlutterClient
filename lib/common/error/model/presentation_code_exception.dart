import 'package:flutter/material.dart';
import 'package:trusttunnel/common/error/exception_utils.dart';
import 'package:trusttunnel/common/error/model/enum/presentation_exception_code.dart';
import 'package:trusttunnel/common/error/model/presentation_exception.dart';
import 'package:trusttunnel/common/localization/localization.dart';

base class PresentationCodeException implements PresentationException {
  final PresentationExceptionCode code;

  const PresentationCodeException({required this.code});

  @override
  String toLocalizedString(BuildContext context) => ExceptionUtils.getBaseExceptionString(code, context.ln);
}

final class PresentationNotFoundException extends PresentationCodeException {
  const PresentationNotFoundException() : super(code: PresentationExceptionCode.notFound);
}
