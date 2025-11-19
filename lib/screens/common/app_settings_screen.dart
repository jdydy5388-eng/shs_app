import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/locale_provider.dart';

class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات التطبيق'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'المظهر',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('الوضع الفاتح'),
                    leading: const Icon(Icons.light_mode),
                    trailing: Radio<ThemeMode>(
                      value: ThemeMode.light,
                      groupValue: themeProvider.themeMode,
                      onChanged: (value) {
                        if (value != null) {
                          themeProvider.setThemeMode(value);
                        }
                      },
                    ),
                  ),
                  ListTile(
                    title: const Text('الوضع المظلم'),
                    leading: const Icon(Icons.dark_mode),
                    trailing: Radio<ThemeMode>(
                      value: ThemeMode.dark,
                      groupValue: themeProvider.themeMode,
                      onChanged: (value) {
                        if (value != null) {
                          themeProvider.setThemeMode(value);
                        }
                      },
                    ),
                  ),
                  ListTile(
                    title: const Text('حسب إعدادات النظام'),
                    leading: const Icon(Icons.brightness_auto),
                    trailing: Radio<ThemeMode>(
                      value: ThemeMode.system,
                      groupValue: themeProvider.themeMode,
                      onChanged: (value) {
                        if (value != null) {
                          themeProvider.setThemeMode(value);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'اللغة',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('العربية'),
                    leading: const Icon(Icons.language),
                    trailing: Radio<Locale>(
                      value: const Locale('ar', 'SA'),
                      groupValue: localeProvider.locale,
                      onChanged: (value) {
                        if (value != null) {
                          localeProvider.setLocale(value);
                        }
                      },
                    ),
                  ),
                  ListTile(
                    title: const Text('English'),
                    leading: const Icon(Icons.language),
                    trailing: Radio<Locale>(
                      value: const Locale('en', 'US'),
                      groupValue: localeProvider.locale,
                      onChanged: (value) {
                        if (value != null) {
                          localeProvider.setLocale(value);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

