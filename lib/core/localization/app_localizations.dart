import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'vi': {},
    'en': {},
  };

  /// Register default and core translations
  static void registerDefaultTranslations({
    required Map<String, String> vi,
    required Map<String, String> en,
  }) {
    _localizedValues['vi']!.addAll(vi);
    _localizedValues['en']!.addAll(en);
  }

  /// Dynamically register translations for modules (like Odoo's po files)
  static void registerModuleTranslations(String localeCode, Map<String, String> translations) {
    if (!_localizedValues.containsKey(localeCode)) {
      _localizedValues[localeCode] = {};
    }
    _localizedValues[localeCode]!.addAll(translations);
  }

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['vi', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension LocalizationExtension on BuildContext {
  String tr(String key) => AppLocalizations.of(this)?.translate(key) ?? key;
}
