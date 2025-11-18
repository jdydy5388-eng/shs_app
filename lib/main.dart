import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'models/user_model.dart';
import 'screens/auth/login_screen.dart';
import 'screens/patient/patient_home_screen.dart';
import 'screens/doctor/doctor_home_screen.dart';
import 'screens/pharmacist/pharmacist_home_screen.dart';
import 'screens/admin/admin_home_screen.dart';

// Local imports (للوضع المحلي)
import 'providers/auth_provider_local.dart';
import 'providers/notification_provider.dart';
import 'services/local_database_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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
        ChangeNotifierProvider(create: (_) {
          final provider = NotificationProvider();
          // تهيئة خدمة الإشعارات
          provider.notificationService.initialize();
          return provider;
        }),
      ],
      child: MaterialApp(
        title: 'النظام الصحي الذكي',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar', 'SA'),
        supportedLocales: const [
          Locale('ar', 'SA'),
          Locale('en', 'US'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            primary: Colors.blue,
            secondary: Colors.green,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 2,
          ),
          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        home: const AuthWrapper(),
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
        default:
          return const LoginScreen();
      }
    }
    return const LoginScreen();
  }
}
