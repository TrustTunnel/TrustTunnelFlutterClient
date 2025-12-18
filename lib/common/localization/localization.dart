import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:trusttunnel/common/localization/generated/l10n.dart';
import 'package:trusttunnel/common/localization/locale_type.dart';

final class Localization {
  static const _delegate = AppLocalizations.delegate;

  static Locale? _deviceLocale;

  const Localization._();

  /// List of supported locales.
  static List<Locale> get supportedLocales => _delegate.supportedLocales;

  static List<Locale> get applicationLocales => List.of([
    defaultLocale,
    ...supportedLocales,
  ]);

  /// List of localization delegates.
  static List<LocalizationsDelegate<void>> get localizationDelegates => [
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    _delegate,
  ];

  /// Context-free translations.
  static AppLocalizations get ln => AppLocalizations.current;

  static Locale get deviceLocale => _deviceLocale ??= WidgetsBinding.instance.platformDispatcher.locale;

  /// Computes the default locale.
  ///
  /// This is the locale that is used when no locale is specified.
  static Locale get defaultLocale {
    if (isDeviceLocaleSupported) return deviceLocale;

    return LocaleType.en.value!;
  }

  static bool get isDeviceLocaleSupported => _delegate.isSupported(deviceLocale);

  static Future<AppLocalizations> load(Locale locale) => AppLocalizations.load(locale);

  /// Obtain [AppLocalizations] instance from [BuildContext].
  static AppLocalizations of(BuildContext context) => AppLocalizations.of(context);
}

extension LocalizationContext on BuildContext {
  AppLocalizations get ln => Localization.of(this);
}
