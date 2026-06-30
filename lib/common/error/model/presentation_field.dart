import 'package:flutter/material.dart';
import 'package:trusttunnel/common/error/exception_utils.dart';
import 'package:trusttunnel/common/error/model/enum/presentation_field_exception_code.dart';
import 'package:trusttunnel/common/error/model/enum/presentation_field_name.dart';
import 'package:trusttunnel/common/localization/localization.dart';

class PresentationField {
  final PresentationFieldExceptionCode code;
  final PresentationFieldName fieldName;

  PresentationField({
    required this.code,
    required this.fieldName,
  });

  String toLocalizedString(BuildContext context) => ExceptionUtils.getFieldExceptionString(this, context.ln);
}
