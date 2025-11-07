import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider_local.dart';
import '../../services/biometric_auth_service.dart';
import '../../services/data_service.dart';
import '../../services/local_data_service.dart';
import '../../services/local_auth_service.dart';
import '../../utils/auth_helper.dart';

class SettingsReportsScreen extends StatefulWidget {
  const SettingsReportsScreen({super.key});

  @override
  State<SettingsReportsScreen> createState() => _SettingsReportsScreenState();
}

class _SettingsReportsScreenState extends State<SettingsReportsScreen>
    with SingleTickerProviderStateMixin {
  final DataService _dataService = DataService();
  final LocalAuthService _authService = LocalAuthService();
  final BiometricAuthService _biometricAuthService = BiometricAuthService();
  late TabController _tabController;
  DoctorStats? _stats;
  bool _isLoadingStats = false;
  bool _isSaving = false;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  bool _systemBiometricEnabled = true;

  // Profile form controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _specializationController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProfile();
    _loadStats();
    _checkBiometric();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _specializationController.dispose();
    _licenseNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = AuthHelper.getCurrentUser(context);
    if (user == null) return;

    setState(() {
      _nameController.text = user.name;
      _emailController.text = user.email;
      _phoneController.text = user.phone;
      _specializationController.text = user.specialization ?? '';
      _licenseNumberController.text = user.licenseNumber ?? '';
    });
  }

  Future<void> _checkBiometric() async {
    final user = AuthHelper.getCurrentUser(context);
    if (user == null) return;

    try {
      final status = await _biometricAuthService.checkBiometricStatus();
      final enabled = await _authService.isUserBiometricEnabled(user.id);

      setState(() {
        _biometricAvailable = status['available'] == true;
        _systemBiometricEnabled = true;
        _biometricEnabled = enabled;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _biometricAvailable = false;
          _systemBiometricEnabled = true;
          _biometricEnabled = false;
        });
      }
    }
  }

  Future<void> _toggleBiometric() async {
    final user = AuthHelper.getCurrentUser(context);
    if (user == null) return;

    if (!_biometricAvailable) {
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
      final scaffoldMessenger = ScaffoldMessenger.of(context);

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
              _buildStep('2', 'انتظر حتى يتم التحقق'),
              _buildStep('3', 'لا تضغط "إلغاء" أثناء عملية التحقق'),
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
                        'تأكد من أن إصبعك نظيف وجاف للحصول على نتائج أفضل.',
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

      bool authenticated = false;
      String? errorMessage;

      try {
        authenticated = await _biometricAuthService.authenticate(
          localizedReason: 'ضع إصبعك على مستشعر البصمة للتفعيل',
          useErrorDialogs: true,
          stickyAuth: true,
        );
      } on PlatformException catch (e) {
        errorMessage = _getBiometricErrorMessage(e.code);
        if (e.code == 'NotEnrolled') {
          errorMessage = '❌ لا توجد بصمة مسجلة في الجهاز!\n\n'
              'قم بتسجيل بصمتك في إعدادات الجهاز أولاً ثم حاول مجدداً.';
        }
      } catch (e) {
        errorMessage = 'خطأ في المصادقة: $e';
      }

      if (authenticated) {
        await _authService.setUserBiometricEnabled(user.id, true);
        if (mounted) {
          setState(() => _biometricEnabled = true);
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('✅ تم تفعيل المصادقة البيومترية بنجاح!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );
          await _checkBiometric();
        }
      } else {
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                errorMessage ??
                    '❌ فشلت المصادقة البيومترية. تأكد من وضع الإصبع بشكل صحيح وحاول مرة أخرى.',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 6),
            ),
          );
          await _checkBiometric();
        }
      }
    } else {
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
        if (mounted) {
          setState(() => _biometricEnabled = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إلغاء تفعيل المصادقة البيومترية'),
              backgroundColor: Colors.orange,
            ),
          );
          await _checkBiometric();
        }
      }
    }
  }

  Future<void> _testBiometric() async {
    if (!mounted) return;

    final navigatorContext = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      bool authenticated = false;
      String? errorMessage;

      try {
        authenticated = await _biometricAuthService.authenticate(
          localizedReason: 'اختبار المصادقة البيومترية',
        );
      } on PlatformException catch (e) {
        errorMessage = _getBiometricErrorMessage(e.code);
      } catch (e) {
        errorMessage = 'خطأ غير متوقع: $e';
      }

      if (!mounted) return;

      navigatorContext.pop();

      if (authenticated) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('✅ المصادقة البيومترية تعمل بشكل صحيح!'),
            backgroundColor: Colors.green,
          ),
        );
        await _checkBiometric();
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              errorMessage ??
                  '❌ فشلت المصادقة البيومترية. تأكد من تسجيل بصمتك في إعدادات الجهاز.',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
        await _checkBiometric();
      }
    } catch (e) {
      if (!mounted) return;
      navigatorContext.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في التحقق: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
        return 'المصادقة البيومترية مقفلة مؤقتاً بسبب المحاولات الخاطئة';
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

  Future<void> _loadStats() async {
    final user = AuthHelper.getCurrentUser(context);
    if (user == null) return;

    setState(() => _isLoadingStats = true);
    try {
      final stats = await _dataService.getDoctorStats(user.id);
      setState(() {
        _stats = stats;
        _isLoadingStats = false;
      });
    } catch (e) {
      setState(() => _isLoadingStats = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل الإحصائيات: $e')),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = AuthHelper.getCurrentUser(context);
    if (user == null) return;

    setState(() => _isSaving = true);
    try {
      final updatedInfo = Map<String, dynamic>.from(user.additionalInfo ?? {});
      updatedInfo['specialization'] = _specializationController.text.trim();
      updatedInfo['licenseNumber'] = _licenseNumberController.text.trim();

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات والتقارير'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'الملف الشخصي', icon: Icon(Icons.person)),
            Tab(text: 'التقارير الإحصائية', icon: Icon(Icons.insights)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProfileTab(),
          _buildReportsTab(),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    final user = AuthHelper.getCurrentUser(context);
    return SingleChildScrollView(
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
                      backgroundColor: Colors.blue.withValues(alpha: 0.2),
                      child: const Icon(Icons.person, size: 40),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? 'الطبيب',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (user?.specialization != null)
                            Text('التخصص: ${user!.specialization}'),
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
                title: const Text('المصادقة البيومترية'),
                subtitle: Text(
                  !_biometricAvailable
                      ? 'الجهاز لا يدعم المصادقة البيومترية أو لا توجد بصمات مسجلة'
                      : _biometricEnabled
                          ? 'مفعلة - يمكنك تسجيل الدخول باستخدام البصمة'
                          : 'غير مفعلة - اضغط لتفعيل المصادقة البيومترية',
                ),
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

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildBiometricStatusRow(
                                  'دعم الجهاز',
                                  supported,
                                  supported
                                      ? 'الجهاز يدعم المصادقة البيومترية ✓'
                                      : 'الجهاز لا يدعم المصادقة البيومترية',
                                ),
                                const SizedBox(height: 8),
                                _buildBiometricStatusRow(
                                  'البصمات المسجلة',
                                  enrolled,
                                  enrolled
                                      ? 'تم تسجيل بصمة في الجهاز ✓'
                                      : 'لا توجد بصمات مسجلة في إعدادات الجهاز',
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
                                          '🔄 ارجع للتطبيق وحاول مرة أخرى',
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
                                            onPressed: () {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'يرجى فتح إعدادات الجهاز يدوياً لتسجيل بصمتك ثم العودة للتطبيق.',
                                                  ),
                                                  duration: Duration(seconds: 4),
                                                ),
                                              );
                                            },
                                            style: OutlinedButton.styleFrom(
                                              side: BorderSide(color: Colors.red[700]!),
                                            ),
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
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'البيانات المهنية',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _specializationController,
              decoration: const InputDecoration(
                labelText: 'التخصص',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.medical_services),
                hintText: 'مثل: طب القلب، طب الأطفال، الجراحة...',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _licenseNumberController,
              decoration: const InputDecoration(
                labelText: 'رقم الرخصة الطبية',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge),
                hintText: 'رقم الرخصة المهنية',
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
          ],
        ),
      ),
    );
  }

  Widget _buildReportsTab() {
    return RefreshIndicator(
      onRefresh: _loadStats,
      child: _isLoadingStats
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _stats == null
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('لا توجد بيانات إحصائية متاحة'),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'نظرة عامة',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.3,
                          children: [
                            _buildStatCard(
                              'إجمالي المرضى',
                              _stats!.totalPatients.toString(),
                              Icons.people,
                              Colors.blue,
                            ),
                            _buildStatCard(
                              'إجمالي الوصفات',
                              _stats!.totalPrescriptions.toString(),
                              Icons.description,
                              Colors.green,
                            ),
                            _buildStatCard(
                              'الوصفات النشطة',
                              _stats!.activePrescriptions.toString(),
                              Icons.medication,
                              Colors.orange,
                            ),
                            _buildStatCard(
                              'المواعيد المكتملة',
                              _stats!.completedAppointments.toString(),
                              Icons.check_circle,
                              Colors.teal,
                            ),
                            _buildStatCard(
                              'المواعيد المعلقة',
                              _stats!.pendingAppointments.toString(),
                              Icons.pending,
                              Colors.amber,
                            ),
                            _buildStatCard(
                              'طلبات الفحوصات المعلقة',
                              _stats!.pendingLabRequests.toString(),
                              Icons.biotech,
                              Colors.purple,
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        _buildDetailedStats(),
                      ],
                    ),
            ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedStats() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'تفاصيل الأداء',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildStatRow(
              'نسبة المواعيد المكتملة',
              _stats!.pendingAppointments + _stats!.completedAppointments > 0
                  ? ((_stats!.completedAppointments /
                              (_stats!.pendingAppointments +
                                  _stats!.completedAppointments)) *
                          100)
                      .toStringAsFixed(1)
                  : '0',
              '%',
              Colors.teal,
            ),
            const Divider(),
            _buildStatRow(
              'متوسط الوصفات لكل مريض',
              _stats!.totalPatients > 0
                  ? (_stats!.totalPrescriptions / _stats!.totalPatients)
                      .toStringAsFixed(1)
                  : '0',
              'وصفة',
              Colors.green,
            ),
            const Divider(),
            _buildStatRow(
              'نسبة الوصفات النشطة',
              _stats!.totalPrescriptions > 0
                  ? ((_stats!.activePrescriptions / _stats!.totalPrescriptions) *
                          100)
                      .toStringAsFixed(1)
                  : '0',
              '%',
              Colors.orange,
            ),
            const SizedBox(height: 16),
            const Text(
              'ملاحظات',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getPerformanceNotes(),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, String unit, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14),
          ),
          Row(
            children: [
              Text(
                '$value $unit',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getPerformanceNotes() {
    if (_stats == null) return 'لا توجد بيانات كافية';
    
    final notes = <String>[];
    
    if (_stats!.totalPatients == 0) {
      notes.add('• لم يتم علاج أي مرضى حتى الآن');
    } else {
      notes.add('• إجمالي المرضى المعالجين: ${_stats!.totalPatients}');
    }
    
    if (_stats!.totalPrescriptions == 0) {
      notes.add('• لم يتم إصدار أي وصفات حتى الآن');
    } else {
      notes.add('• إجمالي الوصفات الصادرة: ${_stats!.totalPrescriptions}');
      if (_stats!.activePrescriptions > 0) {
        notes.add('• الوصفات النشطة الحالية: ${_stats!.activePrescriptions}');
      }
    }
    
    if (_stats!.pendingAppointments > 0) {
      notes.add('• لديك ${_stats!.pendingAppointments} موعد معلق');
    }
    
    if (_stats!.pendingLabRequests > 0) {
      notes.add('• لديك ${_stats!.pendingLabRequests} طلب فحص معلق');
    }
    
    return notes.join('\n');
  }
}

