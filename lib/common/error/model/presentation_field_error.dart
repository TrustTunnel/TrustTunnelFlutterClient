import 'package:flutter/material.dart';
import 'package:trusttunnel/common/error/error_utils.dart';
import 'package:trusttunnel/common/error/model/presentation_error.dart';
import 'package:trusttunnel/common/error/model/presentation_field.dart';
import 'package:trusttunnel/common/localization/generated/l10n.dart';
import 'package:trusttunnel/common/localization/localization.dart';

class PresentationFieldError implements PresentationError {
  final List<PresentationField> fields;

  PresentationFieldError({required this.fields});

  @override
  String toLocalizedString(BuildContext context) {
    AppLocalizations ln = context.ln;

    final StringBuffer buffer = StringBuffer();

    for (int index = 0; index < fields.length; index++) {
      final PresentationField field = fields[index];
      if (index != 0) {
        buffer.writeln();
      }
      buffer.write(ErrorUtils.getFieldErrorString(field, ln));
    }

    return buffer.toString();
  }
}
