import 'package:flutter/material.dart';
import 'package:trusttunnel/common/error/exception_utils.dart';
import 'package:trusttunnel/common/error/model/presentation_exception.dart';
import 'package:trusttunnel/common/error/model/presentation_field.dart';
import 'package:trusttunnel/common/localization/generated/l10n.dart';
import 'package:trusttunnel/common/localization/localization.dart';

class PresentationFieldException implements PresentationException {
  final List<PresentationField> fields;

  const PresentationFieldException({required this.fields});

  @override
  String toLocalizedString(BuildContext context) {
    AppLocalizations ln = context.ln;

    final StringBuffer buffer = StringBuffer();

    for (int index = 0; index < fields.length; index++) {
      final PresentationField field = fields[index];
      if (index != 0) {
        buffer.writeln();
      }
      buffer.write(ExceptionUtils.getFieldExceptionString(field, ln));
    }

    return buffer.toString();
  }
}
