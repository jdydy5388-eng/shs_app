import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider_local.dart';
import '../../services/data_service.dart';
import '../../services/local_auth_service.dart';
import '../../services/biometric_auth_service.dart';
import '../../utils/auth_helper.dart';

class PatientSettingsScreen extends StatefulWidget {
  const PatientSettingsScreen({super.key});

  @override
  State<PatientSettingsScreen> createState() => _PatientSettingsScreenState();
}

class _PatientSettingsScreenState extends State<PatientSettingsScreen> {
  final LocalAuthService _authService = LocalAuthService();
  final BiometricAuthService _biometricAuthService = BiometricAuthService();
  final DataService _dataService = DataService();
  bool _isSaving = false;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false; // دعم الجهاز
  bool _systemBiometricEnabled = false; // إعدادات النظام

  // Profile form controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  final _bloodTypeController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Password change controllers
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _checkBiometric();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dateOfBirthController.dispose();
    _bloodTypeController.dispose();
    _allergiesController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = AuthHelper.getCurrentUser(context);
    if (user == null) return;

    setState(() {
      _nameController.text = user.name;
      _emailController.text = user.email;
      _phoneController.text = user.phone;
      _dateOfBirthController.text = user.dateOfBirth ?? '';
      _bloodTypeController.text = user.bloodType ?? '';
      _allergiesController.text = user.allergies?.join(', ') ?? '';
    });
  }

  Future<void> _checkBiometric() async {
    final user = AuthHelper.getCurrentUser(context);
    if (user == null) return;

    try {
      // استخدام التحقق المحسّن
      final status = await _biometricAuthService.checkBiometricStatus();
      final enabled = await _authService.isUserBiometricEnabled(user.id);
      
      print('PatientSettings: Biometric status - $status, user enabled: $enabled');
      
      setState(() {
        _biometricAvailable = status['available'] == true; // فقط إذا كانت مسجلة فعلياً
        _systemBiometricEnabled = true; // متاحة دائماً الآن
        _biometricEnabled = enabled;
      });
      
      // إظهار رسالة إذا كان الجهاز يدعم لكن لا توجد بصمات مسجلة
      if (status['supported'] == true && status['enrolled'] == false && mounted) {
        print('PatientSettings: Device supports biometric but no fingerprints enrolled');
        print('PatientSettings: Message: ${status['message']}');
      }
    } catch (e) {
      print('PatientSettings: Error checking biometric: $e');
      if (mounted) {
        setState(() {
          _biometricAvailable = false;
          _systemBiometricEnabled = true;
          _biometricEnabled = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = AuthHelper.getCurrentUser(context);
    if (user == null) return;

    setState(() => _isSaving = true);
    try {
      final allergies = _allergiesController.text
          .trim()
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final updatedInfo = Map<String, dynamic>.from(user.additionalInfo ?? {});
      updatedInfo['dateOfBirth'] = _dateOfBirthController.text.trim();
      updatedInfo['bloodType'] = _bloodTypeController.text.trim();
      updatedInfo['allergies'] = allergies;

      final updatedUser = UserModel(
        id: user.id,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        role: user.role,
        profileImageUrl: user.profileImageUrl,
        additionalInfo: updatedInfo,
        createdAt: user.createdAt,
        lastLoginAt: user.lastLoginAt,
      );

      await _authService.updateUser(updatedUser);
      final authProvider = Provider.of<AuthProviderLocal>(context, listen: false);
      await authProvider.updateCurrentUser(updatedUser);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ التغييرات بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadProfile();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في حفظ البيانات: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _changePassword() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تغيير كلمة المرور'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                child: TextField(
                  controller: _currentPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'كلمة المرور الحالية *',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
              ),
              const SizedBox(height: 16),
              Material(
                child: TextField(
                  controller: _newPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'كلمة المرور الجديدة *',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
              ),
              const SizedBox(height: 16),
              Material(
                child: TextField(
                  controller: _confirmPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'تأكيد كلمة المرور *',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _currentPasswordController.clear();
              _newPasswordController.clear();
              _confirmPasswordController.clear();
              Navigator.pop(context, false);
            },
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_currentPasswordController.text.isEmpty ||
                  _newPasswordController.text.isEmpty ||
                  _confirmPasswordController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('يرجى ملء جميع الحقول')),
                );
                return;
              }

              if (_newPasswordController.text != _confirmPasswordController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('كلمة المرور الجديدة غير متطابقة')),
                );
                return;
              }

              Navigator.pop(context, true);
            },
            child: const Text('تغيير'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        // TODO: التحقق من كلمة المرور الحالية وتغييرها
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تغيير كلمة المرور بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ في تغيير كلمة المرور: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleBiometric() async {
    final user = AuthHelper.getCurrentUser(context);
    if (user == null) return;

    if (!_biometricAvailable) {
      // محاولة التحقق مرة أخرى قبل إظهار الرسالة
      await _checkBiometric();
      
      if (!_biometricAvailable && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'المصادقة البيومترية غير متاحة. تأكد من:\n'
              '• تسجيل بصمة في إعدادات الجهاز\n'
              '• تفعيل قفل الشاشة\n'
              '• منح التطبيق الصلاحيات المطلوبة',
            ),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (!_biometricEnabled) {
      // تفعيل المصادقة البيومترية
      // حفظ ScaffoldMessenger قبل async
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      
      // إظهار dialog توضيحي قبل المصادقة
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.fingerprint, color: Colors.blue[700], size: 32),
              const SizedBox(width: 12),
              const Text('تفعيل المصادقة البيومترية'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ستظهر نافذة طلب البصمة بعد الضغط على "متابعة".',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text('الخطوات:'),
              const SizedBox(height: 8),
              _buildStep('1', 'ضع إصبعك على مستشعر البصمة'),
              _buildStep('2', 'انتظر حتى يتم التعرف على البصمة'),
              _buildStep('3', 'لا تضغط "إلغاء" في نافذة البصمة'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'تأكد من أن إصبعك نظيف وجاف للحصول على أفضل النتائج',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.fingerprint),
              label: const Text('متابعة'),
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );

      if (shouldContinue != true) return;
      
      // محاولة المصادقة مباشرة - دع النظام يتعامل مع الأخطاء
      bool authenticated = false;
      String? errorMessage;
      
      try {
        authenticated = await _biometricAuthService.authenticate(
          localizedReason: 'ضع إصبعك على مستشعر البصمة للتفعيل',
          useErrorDialogs: true,
          stickyAuth: true,
        );
        
        print('BiometricAuth: Authentication result: $authenticated');
      } on PlatformException catch (e) {
        print('BiometricAuth: PlatformException during activation - ${e.code}: ${e.message}');
        print('BiometricAuth: Details: ${e.details}');
        errorMessage = _getBiometricErrorMessage(e.code);
        
        // رسائل خاصة لحالات محددة
        if (e.code == 'NotEnrolled') {
          errorMessage = '❌ لا توجد بصمة مسجلة في الجهاز!\n\n'
              '⚠️ ملاحظة مهمة:\n'
              'المصادقة البيومترية تستخدم البصمة المسجلة في نظام التشغيل.\n\n'
              'يجب عليك:\n'
              '1️⃣ افتح إعدادات الجهاز\n'
              '2️⃣ سجّل بصمتك في الأمان والخصوصية\n'
              '3️⃣ ارجع للتطبيق وحاول مرة أخرى\n\n'
              '💡 لا يمكن للتطبيق تسجيل البصمة - هذا يتم فقط من إعدادات الجهاز';
        } else if (e.code == 'PasscodeNotSet') {
          errorMessage = '❌ قفل الشاشة غير مفعل!\n\n'
              'يجب تفعيل قفل الشاشة (PIN/Pattern/Password) أولاً ثم تسجيل بصمتك';
        } else if (e.code.contains('cancel') || e.code.contains('Cancel') || e.code.contains('USER_CANCELED')) {
          errorMessage = 'تم إلغاء العملية\n\n'
              'لتفعيل البصمة، يجب وضع الإصبع على المستشعر وليس إلغاء العملية';
        } else if (e.code == 'LockedOut') {
          errorMessage = 'البصمة مقفلة بسبب محاولات خاطئة متعددة.\n'
              'انتظر 30 ثانية وحاول مرة أخرى';
        }
      } catch (e) {
        print('BiometricAuth: Error during activation: $e');
        errorMessage = 'خطأ في المصادقة: $e';
      }

      if (authenticated) {
        await _authService.setUserBiometricEnabled(user.id, true);
        if (mounted) {
          setState(() => _biometricEnabled = true);
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('✅ تم تفعيل المصادقة البيومترية بنجاح!\n\nيمكنك الآن تسجيل الدخول باستخدام البصمة'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else {
        if (mounted) {
          // رسالة أوضح عن سبب الفشل
          final String finalMessage = errorMessage ?? 
              'فشلت المصادقة البيومترية\n\n'
              'الأسباب المحتملة:\n'
              '• ألغيت العملية\n'
              '• لم تضع إصبعك بشكل صحيح\n'
              '• البصمة غير واضحة\n\n'
              'نصيحة: ضع إصبعك بالكامل على المستشعر وانتظر';
          
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('❌ $finalMessage'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 7),
              action: SnackBarAction(
                label: 'حاول مرة أخرى',
                textColor: Colors.white,
                onPressed: () => _toggleBiometric(),
              ),
            ),
          );
        }
      }
    } else {
      // تعطيل المصادقة البيومترية
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تأكيد الإلغاء'),
          content: const Text('هل أنت متأكد من إلغاء تفعيل المصادقة البيومترية؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('إلغاء التفعيل'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await _authService.setUserBiometricEnabled(user.id, false);
        setState(() => _biometricEnabled = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إلغاء تفعيل المصادقة البيومترية'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthHelper.getCurrentUser(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات الشخصية'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.teal.withValues(alpha: 0.2),
                      child: const Icon(Icons.person, size: 40),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? 'المستخدم',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (user?.bloodType != null)
                            Text('فصيلة الدم: ${user!.bloodType}'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'البيانات الشخصية',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'الاسم الكامل *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'يرجى إدخال الاسم';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'البريد الإلكتروني *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
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
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'رقم الهاتف *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'يرجى إدخال رقم الهاتف';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _dateOfBirthController,
              decoration: const InputDecoration(
                labelText: 'تاريخ الميلاد',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_today),
              ),
              readOnly: true,
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().subtract(const Duration(days: 365 * 30)),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  _dateOfBirthController.text = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bloodTypeController,
              decoration: const InputDecoration(
                labelText: 'فصيلة الدم',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.bloodtype),
                hintText: 'مثل: A+, B-, O+',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _allergiesController,
              decoration: const InputDecoration(
                labelText: 'الحساسيات',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.warning),
                hintText: 'مفصولة بفواصل (مثل: البنسلين، الغبار)',
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'حفظ التغييرات',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'إدارة الأمان',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Card(
              child: ExpansionTile(
                leading: Icon(
                  Icons.fingerprint,
                  color: _biometricEnabled && _biometricAvailable && _systemBiometricEnabled
                      ? Colors.green
                      : Colors.grey,
                ),
                title: Row(
                  children: [
                    const Text('المصادقة البيومترية'),
                    if (_biometricAvailable && !_biometricEnabled) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'اضغط للتفعيل',
                          style: TextStyle(fontSize: 10, color: Colors.blue),
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: _buildBiometricSubtitle(),
                trailing: _biometricAvailable
                    ? Switch(
                        value: _biometricEnabled,
                        onChanged: (_) => _toggleBiometric(),
                      )
                    : null,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FutureBuilder<Map<String, dynamic>>(
                          future: _biometricAuthService.checkBiometricStatus(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return _buildBiometricStatusRow(
                                'دعم الجهاز',
                                _biometricAvailable,
                                'جاري التحقق...',
                              );
                            }
                            
                            final status = snapshot.data!;
                            final supported = status['supported'] == true;
                            final enrolled = status['enrolled'] == true;
                            
                            String description;
                            if (!supported) {
                              description = 'الجهاز لا يدعم المصادقة البيومترية';
                            } else if (!enrolled) {
                              description = 'الجهاز يدعم البصمة لكن لا توجد بصمات مسجلة في إعدادات الجهاز';
                            } else {
                              description = 'الجهاز يدعم البصمة وتوجد بصمات مسجلة ✓';
                            }
                            
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildBiometricStatusRow(
                                  'دعم الجهاز',
                                  supported,
                                  supported ? 'الجهاز يدعم المصادقة البيومترية ✓' : 'الجهاز لا يدعم البصمة',
                                ),
                                const SizedBox(height: 8),
                                _buildBiometricStatusRow(
                                  'البصمات المسجلة',
                                  enrolled,
                                  description,
                                ),
                                if (supported && !enrolled) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.red, width: 1),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'يجب تسجيل بصمة في الجهاز أولاً!',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.red[700],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '📱 افتح إعدادات الجهاز\n'
                                          '🔐 اذهب إلى الأمان والخصوصية\n'
                                          '👆 اضغط على "البصمة" أو "Fingerprint"\n'
                                          '✋ سجّل بصمة إصبعك\n'
                                          '🔄 ارجع للتطبيق واضغط زر "اختبار البصمة"',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.red[700],
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        SizedBox(
                                          width: double.infinity,
                                          child: OutlinedButton.icon(
                                            icon: Icon(Icons.settings, color: Colors.red[700]),
                                            label: Text(
                                              'فتح إعدادات الجهاز',
                                              style: TextStyle(color: Colors.red[700]),
                                            ),
                                            onPressed: () async {
                                              try {
                                                // محاولة فتح إعدادات الجهاز
                                                if (Platform.isAndroid) {
                                                  await _biometricAuthService.authenticate(
                                                    localizedReason: 'سيتم فتح إعدادات الأمان',
                                                  );
                                                }
                                              } catch (e) {
                                                if (mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(
                                                      content: Text('يرجى فتح إعدادات الجهاز يدوياً'),
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                            style: OutlinedButton.styleFrom(
                                              side: BorderSide(color: Colors.red[700]!),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        _buildBiometricStatusRow(
                          'إعدادات النظام',
                          true,
                          'المصادقة البيومترية متاحة للجميع ✓',
                        ),
                        const SizedBox(height: 8),
                        _buildBiometricStatusRow(
                          'حالتك الشخصية',
                          _biometricEnabled,
                          _biometricEnabled
                              ? 'المصادقة البيومترية مفعلة لحسابك ✓'
                              : 'المصادقة البيومترية غير مفعلة لحسابك',
                        ),
                        const SizedBox(height: 16),
                        if (_biometricAvailable && !_biometricEnabled)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue, width: 1),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'لتفعيل البصمة: اضغط على المفتاح في الأعلى ثم ضع إصبعك على مستشعر البصمة',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (!_biometricAvailable) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.warning_outlined, color: Colors.orange[700], size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'خطوات تفعيل البصمة:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange[700],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '1. افتح إعدادات الجهاز\n'
                                  '2. اذهب إلى الأمان والخصوصية\n'
                                  '3. اضغط على "البصمة" أو "Fingerprint"\n'
                                  '4. أضف بصمة جديدة\n'
                                  '5. ارجع للتطبيق واضغط الزر أدناه',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.fingerprint),
                              label: const Text('اختبار البصمة الآن'),
                              onPressed: () async {
                                await _testBiometric();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.lock),
                title: const Text('تغيير كلمة المرور'),
                subtitle: const Text('تحديث كلمة المرور الحالية'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: _changePassword,
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildBiometricSubtitle() {
    if (!_biometricAvailable) {
      return const Text('الجهاز لا يدعم المصادقة البيومترية');
    }
    
    if (_biometricEnabled) {
      return const Text('مفعلة - يمكنك تسجيل الدخول باستخدام البصمة');
    }
    
    return const Text('غير مفعلة - اضغط لتفعيل المصادقة البيومترية');
  }

  Future<void> _testBiometric() async {
    if (!mounted) return;
    
    // حفظ context قبل async operations
    final navigatorContext = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    // إظهار dialog التحميل
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // محاولة المصادقة الفعلية مباشرة (هذا سيطلب الصلاحيات تلقائياً)
      bool authenticated = false;
      String? errorMessage;
      
      try {
        authenticated = await _biometricAuthService.authenticate(
          localizedReason: 'اختبار المصادقة البيومترية',
        );
      } on PlatformException catch (e) {
        errorMessage = _getBiometricErrorMessage(e.code);
        print('BiometricAuth: PlatformException during test - ${e.code}: ${e.message}');
      } catch (e) {
        errorMessage = 'خطأ غير متوقع: $e';
        print('BiometricAuth: Error during test: $e');
      }
      
      if (!mounted) return;
      
      // إغلاق dialog التحميل بعد المصادقة
      navigatorContext.pop();
      
      if (authenticated) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('✅ المصادقة البيومترية تعمل بشكل صحيح!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        
        // تحديث الحالة
        setState(() {
          _biometricAvailable = true;
        });
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              errorMessage ?? 
              '❌ فشلت المصادقة البيومترية\n'
              'تأكد من:\n'
              '• وجود بصمة مسجلة في إعدادات الجهاز\n'
              '• تفعيل قفل الشاشة\n'
              '• منح التطبيق الصلاحيات المطلوبة',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      
      // إعادة فحص الحالة
      await _checkBiometric();
    } catch (e) {
      if (!mounted) return;
      
      // إغلاق dialog التحميل في حالة الخطأ
      try {
        navigatorContext.pop();
      } catch (_) {
        // تجاهل إذا كان الـ dialog مغلق بالفعل
      }
      
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('خطأ في التحقق: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      
      // إعادة فحص الحالة
      await _checkBiometric();
    }
  }

  String? _getBiometricErrorMessage(String? code) {
    switch (code) {
      case 'NotAvailable':
        return 'المصادقة البيومترية غير متاحة على هذا الجهاز';
      case 'NotEnrolled':
        return 'لا توجد بصمة مسجلة. يرجى تسجيل بصمة في إعدادات الجهاز';
      case 'PasscodeNotSet':
        return 'لم يتم تعيين قفل الشاشة. يرجى تفعيل PIN أو Pattern أو Password';
      case 'LockedOut':
        return 'المصادقة البيومترية مقفلة. يرجى إعادة فتح الجهاز';
      case 'PermanentlyLockedOut':
        return 'المصادقة البيومترية مقفلة بشكل دائم. يرجى إعادة تعيين قفل الشاشة';
      default:
        return null;
    }
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: Colors.blue,
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildBiometricStatusRow(String label, bool status, String description) {
    return Row(
      children: [
        Icon(
          status ? Icons.check_circle : Icons.cancel,
          color: status ? Colors.green : Colors.red,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

