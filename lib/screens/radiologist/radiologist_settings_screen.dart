import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/radiology_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider_local.dart';
import '../../services/biometric_auth_service.dart';
import '../../services/data_service.dart';
import '../../services/local_auth_service.dart';
import '../../utils/auth_helper.dart';

class RadiologistSettingsScreen extends StatefulWidget {
  const RadiologistSettingsScreen({super.key});

  @override
  State<RadiologistSettingsScreen> createState() =>
      _RadiologistSettingsScreenState();
}

class _RadiologistSettingsScreenState
    extends State<RadiologistSettingsScreen>
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
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = AuthHelper.getCurrentUser(context);
    if (user == null) return;

    setState(() {
      _nameController.text = user.name;
      _emailController.text = user.email;
      _phoneController.text = user.phone;
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
          const SnackBar(
            content: Text(
              'المصادقة البيومترية غير متاحة. تأكد من:\n'
              '• تسجيل بصمة في إعدادات الجهاز\n'
              '• تفعيل قفل الشاشة\n'
              '• منح التطبيق الصلاحيات المطلوبة',
            ),
            duration: Duration(seconds: 5),
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
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ستظهر نافذة طلب البصمة بعد الضغط على "متابعة".',
                style: TextStyle(fontWeight: FontWeight.bold),
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
      try {
        authenticated = await _biometricAuthService.authenticate(
          localizedReason: 'ضع إصبعك على مستشعر البصمة للتفعيل',
          useErrorDialogs: true,
          stickyAuth: true,
        );
      } catch (e) {
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('خطأ في المصادقة: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (authenticated) {
        await _authService.setUserBiometricEnabled(user.id, true);
        setState(() => _biometricEnabled = true);
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('تم تفعيل المصادقة البيومترية بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تعطيل المصادقة البيومترية'),
          content: const Text('هل أنت متأكد من رغبتك في تعطيل المصادقة البيومترية؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('تعطيل'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await _authService.setUserBiometricEnabled(user.id, false);
        setState(() => _biometricEnabled = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تعطيل المصادقة البيومترية'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }
  }

  Future<void> _loadStats() async {
    try {
      final requests = await _dataService.getRadiologyRequests();

      final totalRequests = requests.length;
      final completedRequests = requests
          .where((r) => (r as RadiologyRequestModel).status == RadiologyStatus.completed)
          .length;
      final requestedRequests = requests
          .where((r) => (r as RadiologyRequestModel).status == RadiologyStatus.requested)
          .length;
      final scheduledRequests = requests
          .where((r) => (r as RadiologyRequestModel).status == RadiologyStatus.scheduled)
          .length;

      // أنواع الأشعة الأكثر طلباً
      final modalityCounts = <String, int>{};
      for (final req in requests) {
        final modality = (req as RadiologyRequestModel).modality;
        modalityCounts[modality] = (modalityCounts[modality] ?? 0) + 1;
      }

      final topModalities = modalityCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      setState(() {
        _stats = {
          'totalRequests': totalRequests,
          'completedRequests': completedRequests,
          'requestedRequests': requestedRequests,
          'scheduledRequests': scheduledRequests,
          'topModalities': topModalities.take(5).toList(),
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
      final updatedUser = UserModel(
        id: user.id,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        role: user.role,
        profileImageUrl: user.profileImageUrl,
        additionalInfo: user.additionalInfo,
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
                      child: const Icon(Icons.medical_services, size: 40),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? 'أخصائي الأشعة',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
                  return 'يرجى إدخال بريد إلكتروني صحيح';
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
              'الأمان',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Card(
              child: SwitchListTile(
                title: const Text('المصادقة البيومترية'),
                subtitle: Text(
                  _biometricEnabled
                      ? 'مفعّلة - استخدم البصمة أو Face ID لتسجيل الدخول'
                      : 'معطّلة - قم بالتفعيل لتسجيل الدخول بسهولة',
                ),
                value: _biometricEnabled && _biometricAvailable && _systemBiometricEnabled,
                onChanged: _biometricAvailable && _systemBiometricEnabled
                    ? (_) => _toggleBiometric()
                    : null,
                secondary: Icon(
                  Icons.fingerprint,
                  color: _biometricEnabled && _biometricAvailable && _systemBiometricEnabled
                      ? Colors.green
                      : Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('حفظ التغييرات'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsTab() {
    if (_stats.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'إحصائيات قسم الأشعة',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'إجمالي الطلبات',
                  _stats['totalRequests']?.toString() ?? '0',
                  Icons.medical_services,
                  Colors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'مكتملة',
                  _stats['completedRequests']?.toString() ?? '0',
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'مطلوبة',
                  _stats['requestedRequests']?.toString() ?? '0',
                  Icons.pending,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'مجدولة',
                  _stats['scheduledRequests']?.toString() ?? '0',
                  Icons.schedule,
                  Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'أنواع الأشعة الأكثر طلباً',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (_stats['topModalities'] != null &&
              (_stats['topModalities'] as List).isNotEmpty)
            ...(_stats['topModalities'] as List).map((entry) {
              final modality = entry.key as String;
              final count = entry.value as int;
              final modalityText = {
                'xray': 'أشعة سينية',
                'ct': 'أشعة مقطعية',
                'mri': 'رنين مغناطيسي',
                'us': 'موجات فوق صوتية',
                'other': 'أخرى',
              }[modality] ?? modality;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.medical_services, color: Colors.purple),
                  title: Text(modalityText),
                  trailing: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            })
          else
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('لا توجد بيانات'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
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
              label,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

