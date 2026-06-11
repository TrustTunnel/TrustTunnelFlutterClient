import 'package:flutter/material.dart';

abstract interface class PresentationException implements Exception {
  String toLocalizedString(BuildContext context);
}
