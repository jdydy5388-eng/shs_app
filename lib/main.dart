import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'models/user_model.dart';
import 'screens/auth/login_screen.dart';
import 'screens/patient/patient_home_screen.dart';
import 'screens/doctor/doctor_home_screen.dart';
import 'screens/pharmacist/pharmacist_home_screen.dart';
import 'screens/admin/admin_home_screen.dart';
import 'screens/lab_technician/lab_technician_home_screen.dart';
import 'screens/radiologist/radiologist_home_screen.dart';
import 'screens/nurse/nurse_home_screen.dart';
import 'screens/receptionist/receptionist_home_screen.dart';
import 'screens/common/splash_screen.dart';

// Local imports (للوضع المحلي)
import 'providers/auth_provider_local.dart';
import 'providers/notification_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/locale_provider.dart';
import 'utils/app_themes.dart';
import 'services/local_database_service.dart';
import 'services/notification_service.dart';
import 'services/advanced_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // تهيئة Firebase (متاح على Android, iOS, Web فقط حالياً)
  // على Windows، Firebase Messaging غير مدعوم بشكل كامل
  // تعطيل Firebase على Windows لتجنب أخطاء الربط
  if (!Platform.isWindows) {
    try {
      // استيراد Firebase فقط على المنصات المدعومة
      // Note: على Windows، سيتم تخطي هذا الكود
      if (kIsWeb) {
        // على الويب، Firebase يعمل
        // await Firebase.initializeApp(
        //   options: DefaultFirebaseOptions.currentPlatform,
        // );
        debugPrint('Firebase will be initialized on web/Android/iOS');
      }
    } catch (e) {
      debugPrint('Warning: Failed to initialize Firebase: $e');
    }
  } else {
    debugPrint('Firebase غير مدعوم على Windows - سيتم استخدام الإشعارات المحلية فقط');
  }
  
  // تهيئة بيانات اللغة العربية للتنسيق
  try {
    await initializeDateFormatting('ar', null);
  } catch (e) {
    // إذا فشلت التهيئة، التطبيق سيستمر بالعمل بدون دعم اللغة العربية
    debugPrint('Warning: Failed to initialize Arabic locale: $e');
  }
  
  // تهيئة قاعدة البيانات المحلية (فقط على المنصات المدعومة، وليس على الويب)
  if (!kIsWeb) {
    try {
      final localDb = LocalDatabaseService();
      await localDb.database; // إنشاء قاعدة البيانات
    } catch (e) {
      debugPrint('Warning: Failed to initialize local database: $e');
    }
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // استخدام Provider المناسب حسب الوضع
        ChangeNotifierProvider(create: (_) => AuthProviderLocal()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) {
          final provider = NotificationProvider();
          // تهيئة خدمة الإشعارات
          provider.notificationService.initialize();
          // تهيئة خدمة الإشعارات المتقدمة
          final advancedService = AdvancedNotificationService();
          advancedService.initialize();
          return provider;
        }),
      ],
      child: Consumer2<ThemeProvider, LocaleProvider>(
        builder: (context, themeProvider, localeProvider, _) {
          return MaterialApp(
            title: 'النظام الصحي الذكي',
            debugShowCheckedModeBanner: false,
            locale: localeProvider.locale,
            supportedLocales: const [
              Locale('ar', 'SA'),
              Locale('en', 'US'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: AppThemes.lightTheme,
            darkTheme: AppThemes.darkTheme,
            themeMode: themeProvider.themeMode,
            builder: (context, child) {
              return Directionality(
                textDirection: localeProvider.locale.languageCode == 'ar'
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                child: child!,
              );
            },
            home: kIsWeb ? const AuthWrapper() : const SplashScreen(),
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProviderLocal>(
      builder: (context, authProvider, _) {
        return _buildHome(authProvider.isAuthenticated, authProvider.currentUser?.role);
      },
    );
  }

  Widget _buildHome(bool isAuthenticated, UserRole? role) {
    if (isAuthenticated) {
      switch (role) {
        case UserRole.patient:
          return const PatientHomeScreen();
        case UserRole.doctor:
          return const DoctorHomeScreen();
        case UserRole.pharmacist:
          return const PharmacistHomeScreen();
        case UserRole.admin:
          return const AdminHomeScreen();
        case UserRole.labTechnician:
          return const LabTechnicianHomeScreen();
        case UserRole.radiologist:
          return const RadiologistHomeScreen();
        case UserRole.nurse:
          return const NurseHomeScreen();
        case UserRole.receptionist:
          return const ReceptionistHomeScreen();
        default:
          return const LoginScreen();
      }
    }
    return const LoginScreen();
  }
}
