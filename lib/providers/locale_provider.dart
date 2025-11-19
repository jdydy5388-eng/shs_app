import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  static const String _localeKey = 'app_locale';
  
  Locale _locale = const Locale('ar', 'SA');

  Locale get locale => _locale;

  LocaleProvider() {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLocale = prefs.getString(_localeKey);
      if (savedLocale != null) {
        final parts = savedLocale.split('_');
        if (parts.length == 2) {
          _locale = Locale(parts[0], parts[1]);
          notifyListeners();
        }
      }
    } catch (e) {
      // استخدام الوضع الافتراضي في حالة الخطأ
    }
  }

  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localeKey, '${locale.languageCode}_${locale.countryCode}');
    } catch (e) {
      // تجاهل الخطأ
    }
  }

  void toggleLanguage() {
    if (_locale.languageCode == 'ar') {
      setLocale(const Locale('en', 'US'));
    } else {
      setLocale(const Locale('ar', 'SA'));
    }
  }
}

