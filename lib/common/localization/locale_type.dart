import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';

enum LocaleType {
  system(null),
  en(Locale('en', 'GB')),
  de(Locale('de')),
  fr(Locale('fr')),
  it(Locale('it')),
  ru(Locale('ru')),
  ja(Locale('ja')),
  zh(Locale('zh')),
  ko(Locale('ko'));

  final Locale? value;

  const LocaleType(this.value);

  factory LocaleType.fromString(String value) => values.firstWhere((e) => e.name == value);

  static LocaleType? fromLocale(Locale locale) =>
      values.firstWhereOrNull((e) => e.value?.languageCode == locale.languageCode);
}
