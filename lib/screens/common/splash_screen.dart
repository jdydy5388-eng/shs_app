import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../providers/auth_provider_local.dart';
import '../../models/user_model.dart';
import '../auth/login_screen.dart';
import '../patient/patient_home_screen.dart';
import '../doctor/doctor_home_screen.dart';
import '../pharmacist/pharmacist_home_screen.dart';
import '../admin/admin_home_screen.dart';
import 'package:provider/provider.dart';

/// شاشة البداية (Splash Screen) - تظهر عند فتح التطبيق
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    // تهيئة التحريك
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    // بدء التحريك
    _controller.forward();

    // الانتقال للشاشة التالية بعد 2.5 ثانية
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        _navigateToNextScreen();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigateToNextScreen() {
    final authProvider = Provider.of<AuthProviderLocal>(context, listen: false);
    final isAuthenticated = authProvider.isAuthenticated;
    final role = authProvider.currentUser?.role;

    Widget nextScreen;
    if (isAuthenticated) {
      switch (role) {
        case UserRole.patient:
          nextScreen = const PatientHomeScreen();
          break;
        case UserRole.doctor:
          nextScreen = const DoctorHomeScreen();
          break;
        case UserRole.pharmacist:
          nextScreen = const PharmacistHomeScreen();
          break;
        case UserRole.admin:
          nextScreen = const AdminHomeScreen();
          break;
        default:
          nextScreen = const LoginScreen();
      }
    } else {
      nextScreen = const LoginScreen();
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => nextScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue, // نفس لون الخلفية في Android
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // الأيقونة
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1A237E),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // القلب
                      CustomPaint(
                        size: const Size(80, 80),
                        painter: HeartPainter(),
                      ),
                      // الصليب الطبي
                      const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 30,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                // النص
                const Text(
                  'النظام الصحي الذكي',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// رسام مخصص لرسم القلب
class HeartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4CAF50)
      ..style = PaintingStyle.fill;

    final path = Path();
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final width = size.width;
    final height = size.height;

    // رسم القلب بشكل متماثل
    path.moveTo(centerX, centerY + height * 0.2);
    
    // الجانب الأيسر من القلب
    path.cubicTo(
      centerX - width * 0.1, centerY + height * 0.1,
      centerX - width * 0.25, centerY - height * 0.05,
      centerX - width * 0.2, centerY - height * 0.2,
    );
    path.cubicTo(
      centerX - width * 0.15, centerY - height * 0.3,
      centerX - width * 0.05, centerY - height * 0.25,
      centerX, centerY - height * 0.15,
    );
    
    // الجانب الأيمن من القلب
    path.cubicTo(
      centerX + width * 0.05, centerY - height * 0.25,
      centerX + width * 0.15, centerY - height * 0.3,
      centerX + width * 0.2, centerY - height * 0.2,
    );
    path.cubicTo(
      centerX + width * 0.25, centerY - height * 0.05,
      centerX + width * 0.1, centerY + height * 0.1,
      centerX, centerY + height * 0.2,
    );
    
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

