import 'package:flutter/material.dart';
import 'package:trusttunnel/common/error/error_utils.dart';
import 'package:trusttunnel/common/error/model/enum/presentation_error_code.dart';
import 'package:trusttunnel/common/error/model/presentation_error.dart';
import 'package:trusttunnel/common/localization/localization.dart';

base class PresentationBaseError implements PresentationError {
  final PresentationErrorCode code;

  PresentationBaseError({required this.code});

  @override
  String toLocalizedString(BuildContext context) => ErrorUtils.getBaseErrorString(code, context.ln);
}

final class PresentationNotFoundError extends PresentationBaseError {
  PresentationNotFoundError() : super(code: PresentationErrorCode.notFound);
}
