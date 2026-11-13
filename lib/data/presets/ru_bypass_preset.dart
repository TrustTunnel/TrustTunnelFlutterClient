import 'package:trusttunnel/data/model/installed_app.dart';

/// {@template ru_bypass_preset}
/// Curated Runet bypass presets.
///
/// Contains:
/// - [domains]: domain rules that, combined with the downloaded RU CIDR list,
///   keep Russian websites and services outside the VPN tunnel. Domain rules
///   are suffix-matched by the VPN core, so the `ru`/`su`/`рф` TLD entries
///   cover every site in these zones.
/// - [apps]: popular Russian Android applications recommended for per-app
///   exclusion (banks, messengers, marketplaces).
/// {@endtemplate}
abstract final class RuBypassPreset {
  /// Source of the Russian IP ranges: RIPE NCC country resource list for RU
  /// (all IPv4/IPv6 prefixes delegated to Russia, refreshed daily).
  static final Uri cidrListUrl = Uri.parse('https://stat.ripe.net/data/country-resource-list/data.json?resource=RU');

  /// Domain rules added to the effective exclusions when Runet bypass is on.
  ///
  /// Stored without a leading dot; the VPN core matches by suffix, and the
  /// app adds `*.` wildcard variants when building the configuration.
  static const List<String> domains = [
    // --- TLDs: cover all .ru / .su / .рф sites ---
    'ru',
    'su',
    'рф',
    'xn--p1ai', // punycode for .рф

    // --- Yandex ---
    'yandex.ru',
    'yandex.net',
    'yandex.com',
    'yandex.cloud',
    'yandex-team.ru',
    'yastatic.net',
    'ya.ru',
    'yandex.st',
    'kinopoisk.ru',
    'yandexdisk.ru',

    // --- VK ---
    'vk.com',
    'vk.me',
    'userapi.com',
    'vkontakte.ru',

    // --- Mail.ru Group ---
    'mail.ru',
    'ok.ru',
    'list.ru',
    'bk.ru',
    'inbox.ru',
    'corp.mail.ru',
    'odnoklassniki.ru',
    'my.com',

    // --- MAX messenger (VK) ---
    'max.ru',
    'web.max.ru',
    'platform-api.max.ru',
    'platform-api2.max.ru',
    'dev.max.ru',
    'oneme.ru',
    'api-gost.oneme.ru',

    // --- VK Analytics / MyTracker (used by MAX and other VK apps) ---
    // NOTE: mytracker.com is NOT covered by the `ru` TLD rule.
    'mytracker.ru',
    'mytracker.com',
    'vk-analytics.ru',
    'tracker-api.vk-analytics.ru',

    // --- Marketplaces ---
    'avito.ru',
    'ozon.ru',
    'wildberries.ru',
    'lamoda.ru',
    'cian.ru',
    'auto.ru',
    'drom.ru',

    // --- Media / video ---
    'rutube.ru',
    'rbc.ru',
    'lenta.ru',
    'rt.com',
    'ria.ru',
    'tass.ru',
    '1tv.ru',
    'vgtrk.ru',
    'kp.ru',

    // --- IT ---
    'habr.ru',
    'habr.com',

    // --- Government ---
    'gosuslugi.ru',
    'pfr.gov.ru',
    'nalog.gov.ru',
    'customsonline.ru',
    'gost.ru',
    'mos.ru',
    'mosreg.ru',
    'rosreestr.gov.ru',
    'gu.spb.ru',

    // --- Jobs ---
    'hh.ru',
    'hhcdn.ru',

    // --- Banks (RU-TLD ones are covered by TLD rules; listed for clarity) ---
    'tbank.ru',
    'tinkoff.ru',
    'tinkoffinsurance.ru',
    'sberbank.ru',
    'sber.ru',
    'sberdevices.ru',
    'vtb.ru',
    'vtb24.ru',
    'alfabank.ru',
    'raiffeisen.ru',
    'psbank.ru',
    'gazprombank.ru',

    // --- Telecom ---
    'mts.ru',
    'beeline.ru',
    'megafon.ru',
    'tele2.ru',
    'rostelecom.ru',
  ];

  /// Popular Russian Android applications recommended for exclusion.
  static const List<RuAppPreset> apps = [
    RuAppPreset(packageName: 'ru.max.messenger.makc', name: 'MAX'),
    RuAppPreset(packageName: 'ru.oneme.app', name: 'MAX (beta, ex-OneMe)'),
    RuAppPreset(packageName: 'ru.sberbankmobile', name: 'SberBank'),
    RuAppPreset(packageName: 'com.idamob.tinkoff.android', name: 'T-Bank (Tinkoff)'),
    RuAppPreset(packageName: 'ru.vtb24.mobilebanking', name: 'VTB'),
    RuAppPreset(packageName: 'ru.alfabank.mobile.android', name: 'Alfa-Bank'),
    RuAppPreset(packageName: 'com.psbank.mbank', name: 'Promsvyazbank'),
    RuAppPreset(packageName: 'ru.gazprombank.android.mobilebank.app', name: 'Gazprombank'),
    RuAppPreset(packageName: 'ru.raiffeisennews', name: 'Raiffeisen Bank'),
    RuAppPreset(packageName: 'com.raiffeisen.mbanking', name: 'Raiffeisen Bank (alt)'),
    RuAppPreset(packageName: 'ru.yandex.mobile.search', name: 'Yandex'),
    RuAppPreset(packageName: 'ru.yandex.searchplugin', name: 'Yandex (widget)'),
    RuAppPreset(packageName: 'com.vk.android', name: 'VK'),
    RuAppPreset(packageName: 'ru.ok.android', name: 'Odnoklassniki'),
    RuAppPreset(packageName: 'ru.mail.mailapp', name: 'Mail.ru'),
    RuAppPreset(packageName: 'ru.avito', name: 'Avito'),
    RuAppPreset(packageName: 'com.wildberries.ru', name: 'Wildberries'),
    RuAppPreset(packageName: 'ru.ozon.android', name: 'Ozon'),
    RuAppPreset(packageName: 'ru.hh.android', name: 'HeadHunter'),
  ];
}
