import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/biometric_auth_service.dart';
import '../../services/data_service.dart';
import '../../services/local_auth_service.dart';
import '../patient/patient_home_screen.dart';
import '../doctor/doctor_home_screen.dart';
import '../pharmacist/pharmacist_home_screen.dart';
import '../admin/admin_home_screen.dart';
import '../lab_technician/lab_technician_home_screen.dart';
import '../radiologist/radiologist_home_screen.dart';
import '../nurse/nurse_home_screen.dart';
import '../receptionist/receptionist_home_screen.dart';
import 'register_screen.dart';
import '../../providers/auth_provider_local.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _biometricAuthService = BiometricAuthService();
  final _dataService = DataService();
  final _authService = LocalAuthService();
  bool _obscurePassword = true;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    final available = await _biometricAuthService.isBiometricAvailable();
    final biometricUserId = await _authService.getBiometricUserId();
    final hasUserWithBiometric = biometricUserId != null;
    
    setState(() {
      _biometricEnabled = true; // متاحة دائماً الآن
      _biometricAvailable = available && hasUserWithBiometric;
    });
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProviderLocal>(context, listen: false);
    final success = await authProvider.signInWithEmailAndPassword(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (success && mounted) {
      // إعادة فحص حالة البصمة بعد تسجيل الدخول
      await _checkBiometricAvailability();
      _navigateToHome(authProvider.currentUser!.role);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'خطأ في تسجيل الدخول'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleBiometricLogin() async {
    final authProvider = Provider.of<AuthProviderLocal>(context, listen: false);
    final success = await authProvider.signInWithBiometric();

    if (success && mounted) {
      if (authProvider.currentUser != null) {
        _navigateToHome(authProvider.currentUser!.role);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يوجد مستخدم مسجل. يرجى تسجيل الدخول أولاً'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'فشلت المصادقة البيومترية'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToHome(UserRole userRole) {
    switch (userRole) {
      case UserRole.patient:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PatientHomeScreen()),
        );
        break;
      case UserRole.doctor:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DoctorHomeScreen()),
        );
        break;
      case UserRole.pharmacist:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PharmacistHomeScreen()),
        );
        break;
      case UserRole.admin:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminHomeScreen()),
        );
        break;
      case UserRole.labTechnician:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LabTechnicianHomeScreen()),
        );
        break;
      case UserRole.radiologist:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const RadiologistHomeScreen()),
        );
        break;
      case UserRole.nurse:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const NurseHomeScreen()),
        );
        break;
      case UserRole.receptionist:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ReceptionistHomeScreen()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),
                const Icon(
                  Icons.medical_services,
                  size: 100,
                  color: Colors.blue,
                ),
                const SizedBox(height: 24),
                const Text(
                  'النظام الصحي الذكي',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 48),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'البريد الإلكتروني',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'يرجى إدخال البريد الإلكتروني';
                    }
                    if (!value.contains('@')) {
                      return 'البريد الإلكتروني غير صحيح';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'يرجى إدخال كلمة المرور';
                    }
                    if (value.length < 6) {
                      return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                Consumer<AuthProviderLocal>(
                  builder: (context, authProvider, _) {
                    return ElevatedButton(
                      onPressed: authProvider.isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: authProvider.isLoading
                          ? const CircularProgressIndicator()
                          : const Text(
                              'تسجيل الدخول',
                              style: TextStyle(fontSize: 18),
                            ),
                    );
                  },
                ),
                if (_biometricAvailable) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _handleBiometricLogin,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('المصادقة البيومترية'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    );
                  },
                  child: const Text('ليس لديك حساب؟ سجل الآن'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

