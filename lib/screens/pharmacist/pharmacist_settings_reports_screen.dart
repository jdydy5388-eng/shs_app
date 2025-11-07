import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider_local.dart';
import '../../services/biometric_auth_service.dart';
import '../../services/data_service.dart';
import '../../services/local_auth_service.dart';
import '../../utils/auth_helper.dart';

class PharmacistSettingsReportsScreen extends StatefulWidget {
  const PharmacistSettingsReportsScreen({super.key});

  @override
  State<PharmacistSettingsReportsScreen> createState() =>
      _PharmacistSettingsReportsScreenState();
}

class _PharmacistSettingsReportsScreenState
    extends State<PharmacistSettingsReportsScreen>
    with SingleTickerProviderStateMixin {
  final DataService _dataService = DataService();
  final LocalAuthService _authService = LocalAuthService();
  final BiometricAuthService _biometricAuthService = BiometricAuthService();
  late TabController _tabController;
  bool _isSaving = false;
  Map<String, dynamic> _stats = {};
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  bool _systemBiometricEnabled = true;

  // Profile form controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _pharmacyNameController = TextEditingController();
  final _pharmacyAddressController = TextEditingController();
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
    _pharmacyNameController.dispose();
    _pharmacyAddressController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = AuthHelper.getCurrentUser(context);
    if (user == null) return;

    setState(() {
      _nameController.text = user.name;
      _emailController.text = user.email;
      _phoneController.text = user.phone;
      _pharmacyNameController.text = user.pharmacyName ?? '';
      _pharmacyAddressController.text = user.pharmacyAddress ?? '';
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
                        'تأكد من أن إصبعك نظيف وجاف للحصول على نتائج أفضل',
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

    try {
      final orders = await _dataService.getOrders(pharmacyId: user.id);
      final inventory = await _dataService.getInventory(pharmacyId: user.id);

      final totalOrders = orders.length;
      final completedOrders = orders.where((o) => o.status == OrderStatus.delivered).length;
      final pendingOrders = orders.where((o) => o.status == OrderStatus.pending).length;
      final lowStockItems = inventory.where((item) => item.isLowStock).length;
      final outOfStockItems = inventory.where((item) => item.isOutOfStock).length;

      // الأدوية الأكثر طلباً
      final medicationCounts = <String, int>{};
      for (final order in orders) {
        for (final item in order.items) {
          medicationCounts[item.medicationName] =
              (medicationCounts[item.medicationName] ?? 0) + (item.quantity as num).toInt();
        }
      }

      final topMedications = medicationCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      setState(() {
        _stats = {
          'totalOrders': totalOrders,
          'completedOrders': completedOrders,
          'pendingOrders': pendingOrders,
          'lowStockItems': lowStockItems,
          'outOfStockItems': outOfStockItems,
          'totalInventoryItems': inventory.length,
          'topMedications': topMedications.take(5).toList(),
        };
      });
    } catch (e) {
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
      updatedInfo['pharmacyName'] = _pharmacyNameController.text.trim();
      updatedInfo['pharmacyAddress'] = _pharmacyAddressController.text.trim();

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
        title: const Text('التقارير والإعدادات'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'الإعدادات', icon: Icon(Icons.settings)),
            Tab(text: 'التقارير', icon: Icon(Icons.insights)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSettingsTab(),
          _buildReportsTab(),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
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
                      backgroundColor: Colors.purple.withValues(alpha: 0.2),
                      child: const Icon(Icons.local_pharmacy, size: 40),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? 'الصيدلي',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (user?.pharmacyName != null)
                            Text('الصيدلية: ${user!.pharmacyName}'),
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
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.fingerprint,
                          color: _biometricEnabled ? Colors.green : Colors.grey,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'تسجيل الدخول بالبصمة',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                _biometricEnabled
                                    ? 'تم تفعيل المصادقة البيومترية لحسابك'
                                    : 'قم بتفعيل المصادقة البيومترية لتسجيل الدخول بسرعة وأمان',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _biometricEnabled,
                          onChanged: (_) => _toggleBiometric(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (!_systemBiometricEnabled)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.lock_outline, color: Colors.orange),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'تم تعطيل المصادقة البيومترية من إعدادات النظام. يرجى التواصل مع مدير النظام.',
                                style: TextStyle(
                                  color: Colors.orange[900],
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FutureBuilder<Map<String, dynamic>>(
                            future: _biometricAuthService.checkBiometricStatus(),
                            builder: (context, snapshot) {
                              final supported = snapshot.data?['supported'] == true;
                              final enrolled = snapshot.data?['enrolled'] == true;
                              final available = snapshot.data?['available'] == true;
                              final error = snapshot.data?['message'];

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildBiometricStatusRow(
                                    'الجهاز يدعم البصمة',
                                    supported,
                                    supported
                                        ? 'جهازك يدعم المصادقة البيومترية'
                                        : 'الجهاز الحالي لا يدعم البصمة أو مستشعر الوجه',
                                  ),
                                  const SizedBox(height: 8),
                                  _buildBiometricStatusRow(
                                    'تم تسجيل بصمة',
                                    enrolled,
                                    enrolled
                                        ? 'يوجد بصمة مسجلة في إعدادات الجهاز'
                                        : 'لا توجد بصمة مسجلة. قم بتسجيل بصمة عبر إعدادات الجهاز',
                                  ),
                                  const SizedBox(height: 8),
                                  _buildBiometricStatusRow(
                                    'متاح للاستخدام الآن',
                                    available && _biometricAvailable,
                                    available && _biometricAvailable
                                        ? 'يمكنك استخدام البصمة لتسجيل الدخول'
                                        : 'تحقق من تسجيل بصمة ومنح التطبيق الصلاحيات المطلوبة',
                                  ),
                                  if (error != null) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      'تفاصيل:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      error.toString(),
                                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: _testBiometric,
                                icon: const Icon(Icons.play_arrow),
                                label: const Text('تجربة المصادقة الآن'),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                onPressed: _checkBiometric,
                                icon: const Icon(Icons.refresh),
                                label: const Text('تحديث الحالة'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'نصائح:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          _buildStep('1', 'تأكد من تسجيل بصمتك في إعدادات الجهاز'),
                          _buildStep('2', 'قم بتمكين قفل الشاشة (PIN / Password / Pattern)'),
                          _buildStep('3', 'امنح التطبيق صلاحية استخدام البصمة عند ظهور الطلب'),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'بيانات الصيدلية',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _pharmacyNameController,
              decoration: const InputDecoration(
                labelText: 'اسم الصيدلية',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.local_pharmacy),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _pharmacyAddressController,
              decoration: const InputDecoration(
                labelText: 'عنوان الصيدلية',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
              maxLines: 2,
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'نظرة عامة',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                  'إجمالي الطلبات',
                  '${_stats['totalOrders'] ?? 0}',
                  Icons.shopping_cart,
                  Colors.blue,
                ),
                _buildStatCard(
                  'الطلبات المكتملة',
                  '${_stats['completedOrders'] ?? 0}',
                  Icons.check_circle,
                  Colors.green,
                ),
                _buildStatCard(
                  'الطلبات المعلقة',
                  '${_stats['pendingOrders'] ?? 0}',
                  Icons.pending,
                  Colors.orange,
                ),
                _buildStatCard(
                  'مخزون منخفض',
                  '${_stats['lowStockItems'] ?? 0}',
                  Icons.warning,
                  Colors.amber,
                ),
                _buildStatCard(
                  'نفد المخزون',
                  '${_stats['outOfStockItems'] ?? 0}',
                  Icons.error,
                  Colors.red,
                ),
                _buildStatCard(
                  'إجمالي الأدوية',
                  '${_stats['totalInventoryItems'] ?? 0}',
                  Icons.medication,
                  Colors.purple,
                ),
              ],
            ),
            const SizedBox(height: 32),
            if ((_stats['topMedications'] as List?)?.isNotEmpty == true) ...[
              const Text(
                'الأدوية الأكثر طلباً',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: (_stats['topMedications'] as List)
                      .asMap()
                      .entries
                      .map((entry) {
                    final index = entry.key;
                    final medication = entry.value as MapEntry<String, int>;
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text('${index + 1}'),
                      ),
                      title: Text(medication.key),
                      trailing: Text(
                        '${medication.value}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: const Text('وحدة'),
                    );
                  }).toList(),
                ),
              ),
            ],
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
}

