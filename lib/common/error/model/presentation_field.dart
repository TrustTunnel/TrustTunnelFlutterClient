import 'package:flutter/material.dart';
import 'package:trusttunnel/common/error/error_utils.dart';
import 'package:trusttunnel/common/error/model/enum/presentation_field_error_code.dart';
import 'package:trusttunnel/common/error/model/enum/presentation_field_name.dart';
import 'package:trusttunnel/common/localization/localization.dart';

class PresentationField {
  final PresentationFieldErrorCode code;
  final PresentationFieldName fieldName;

  PresentationField({
    required this.code,
    required this.fieldName,
  });

  String toLocalizedString(BuildContext context) => ErrorUtils.getFieldErrorString(this, context.ln);
}
