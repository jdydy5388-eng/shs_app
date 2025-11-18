import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/audit_log_model.dart';
import '../../models/user_model.dart';
import '../../models/entity_model.dart';
import '../../models/system_settings_model.dart';
import '../../services/biometric_auth_service.dart';
import '../../services/local_auth_service.dart';
import '../../services/data_service.dart';
import '../../utils/auth_helper.dart';
import '../../widgets/loading_widgets.dart';
import '../../widgets/status_banner.dart';

class SystemMonitoringScreen extends StatefulWidget {
  const SystemMonitoringScreen({super.key});

  @override
  State<SystemMonitoringScreen> createState() => _SystemMonitoringScreenState();
}

class _SystemMonitoringScreenState extends State<SystemMonitoringScreen>
    with SingleTickerProviderStateMixin {
  final _dataService = DataService();
  final LocalAuthService _localAuthService = LocalAuthService();
  late TabController _tabController;
  List<AuditLogModel> _auditLogs = [];
  bool _isLoading = true;
  AuditAction? _filterAction;

  final BiometricAuthService _biometricAuthService = BiometricAuthService();
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  bool _isLoadingSettings = false;
  bool _userBiometricEnabled = false;
  bool _userBiometricAvailable = false;
  bool _isCheckingUserBiometric = false;
  Map<String, dynamic>? _userBiometricStatus;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAuditLogs();
    _loadSystemSettings();
    _checkUserBiometric();
  }

  Future<void> _loadSystemSettings() async {
    setState(() => _isLoadingSettings = true);
    try {
      final enabled = await _dataService.isBiometricEnabled();
      final available = await _biometricAuthService.isBiometricAvailable();
      setState(() {
        _biometricEnabled = enabled;
        _biometricAvailable = available;
        _isLoadingSettings = false;
      });
      await _checkUserBiometric();
    } catch (e) {
      setState(() => _isLoadingSettings = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل الإعدادات: $e')),
        );
      }
    }
  }

  Future<void> _checkUserBiometric() async {
    final user = AuthHelper.getCurrentUser(context);
    if (user == null) return;

    setState(() {
      _isCheckingUserBiometric = true;
    });

    try {
      final status = await _biometricAuthService.checkBiometricStatus();
      final enabled = await _localAuthService.isUserBiometricEnabled(user.id);

      if (!mounted) return;

      setState(() {
        _userBiometricStatus = status;
        _userBiometricAvailable = status['available'] == true;
        _userBiometricEnabled = enabled;
        _isCheckingUserBiometric = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _userBiometricStatus = {'message': e.toString()};
        _userBiometricAvailable = false;
        _userBiometricEnabled = false;
        _isCheckingUserBiometric = false;
      });
    }
  }

  Future<void> _toggleUserBiometric() async {
    final user = AuthHelper.getCurrentUser(context);
    if (user == null) return;

    if (!_biometricEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن التفعيل لأن المصادقة البيومترية معطلة على مستوى النظام'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_userBiometricAvailable) {
      await _checkUserBiometric();
      if (!_userBiometricAvailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'المصادقة البيومترية غير متاحة. تأكد من تسجيل بصمة ومنح الصلاحيات للتطبيق.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    if (!_userBiometricEnabled) {
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.fingerprint, color: Colors.blue[700], size: 32),
              const SizedBox(width: 12),
              const Text('تفعيل تسجيل الدخول بالبصمة'),
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
              _buildStep('2', 'انتظر حتى ينجح التحقق'),
              _buildStep('3', 'تجنب الضغط على زر الإلغاء أثناء العملية'),
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
                        'تأكد من أن المستشعر نظيف وأن إصبعك جاف لتحسين نجاح التحقق.',
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
          localizedReason: 'ضع إصبعك على المستشعر لتفعيل تسجيل الدخول بالبصمة',
          useErrorDialogs: true,
          stickyAuth: true,
        );
      } on PlatformException catch (e) {
        errorMessage = _getBiometricErrorMessage(e.code);
        if (e.code == 'NotEnrolled') {
          errorMessage = 'لا توجد بصمة مسجلة في الجهاز. قم بتسجيل بصمتك أولاً ثم حاول مجدداً.';
        }
      } catch (e) {
        errorMessage = 'خطأ في المصادقة: $e';
      }

      if (authenticated) {
        await _localAuthService.setUserBiometricEnabled(user.id, true);
        if (!mounted) return;
        setState(() => _userBiometricEnabled = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تفعيل تسجيل الدخول بالبصمة بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        await _checkUserBiometric();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMessage ?? 'فشلت المصادقة البيومترية. تأكد من وضع الإصبع بشكل صحيح وحاول مرة أخرى.',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
        await _checkUserBiometric();
      }
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('إلغاء تفعيل البصمة'),
          content: const Text('هل أنت متأكد من إلغاء تفعيل تسجيل الدخول بالبصمة لهذا الحساب؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('لا'),
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
        await _localAuthService.setUserBiometricEnabled(user.id, false);
        if (!mounted) return;
        setState(() => _userBiometricEnabled = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تعطيل تسجيل الدخول بالبصمة'),
            backgroundColor: Colors.orange,
          ),
        );
        await _checkUserBiometric();
      }
    }
  }

  Future<void> _testUserBiometric() async {
    if (!_biometricEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('المصادقة البيومترية معطلة على مستوى النظام. قم بتفعيلها أولاً.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    bool authenticated = false;
    String? errorMessage;

    try {
      authenticated = await _biometricAuthService.authenticate(
        localizedReason: 'اختبار المصادقة البيومترية للحساب الإداري',
      );
    } on PlatformException catch (e) {
      errorMessage = _getBiometricErrorMessage(e.code);
    } catch (e) {
      errorMessage = 'خطأ في التحقق: $e';
    }

    if (!mounted) return;

    Navigator.of(context, rootNavigator: true).pop();

    if (authenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('نجحت المصادقة البيومترية!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMessage ?? 'فشل اختبار المصادقة. تأكد من تسجيل بصمتك في إعدادات الجهاز.',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }

    await _checkUserBiometric();
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

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAuditLogs() async {
    setState(() => _isLoading = true);
    try {
      final logs = await _dataService.getAuditLogs();
      setState(() {
        _auditLogs = logs.cast<AuditLogModel>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل السجلات: $e')),
        );
      }
    }
  }

  List<AuditLogModel> get _filteredLogs {
    if (_filterAction == null) return _auditLogs;
    return _auditLogs.where((log) => log.action == _filterAction).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مراقبة النظام والأمان'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.assessment), text: 'الإحصائيات'),
            Tab(icon: Icon(Icons.description), text: 'التقارير'),
            Tab(icon: Icon(Icons.history), text: 'سجلات التدقيق'),
            Tab(icon: Icon(Icons.settings), text: 'الإعدادات'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAuditLogs,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStatisticsTab(),
          _buildReportsTab(),
          _buildAuditLogsTab(),
          _buildSettingsTab(),
        ],
      ),
    );
  }

  Widget _buildStatisticsTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadStatistics(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ListSkeletonLoader(itemCount: 8);
        }

        if (snapshot.hasError) {
          return ErrorStateWidget(
            message: 'فشل تحميل الإحصائيات: ${snapshot.error}',
            onRetry: () {
              setState(() {});
            },
          );
        }

        final stats = snapshot.data ?? {};

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'إحصائيات النظام',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              _buildStatCard(
                'إجمالي المستخدمين',
                '${stats['totalUsers'] ?? 0}',
                Icons.people,
                Colors.blue,
              ),
              const SizedBox(height: 16),
              _buildStatCard(
                'الأطباء',
                '${stats['doctors'] ?? 0}',
                Icons.medical_services,
                Colors.green,
              ),
              const SizedBox(height: 16),
              _buildStatCard(
                'الصيادلة',
                '${stats['pharmacists'] ?? 0}',
                Icons.local_pharmacy,
                Colors.purple,
              ),
              const SizedBox(height: 16),
              _buildStatCard(
                'المرضى',
                '${stats['patients'] ?? 0}',
                Icons.person,
                Colors.orange,
              ),
              const SizedBox(height: 24),
              _buildStatCard(
                'إجمالي الوصفات',
                '${stats['totalPrescriptions'] ?? 0}',
                Icons.description,
                Colors.teal,
              ),
              const SizedBox(height: 16),
              _buildStatCard(
                'إجمالي الطلبات',
                '${stats['totalOrders'] ?? 0}',
                Icons.shopping_cart,
                Colors.indigo,
              ),
              const SizedBox(height: 16),
              _buildStatCard(
                'الصيدليات',
                '${stats['pharmacies'] ?? 0}',
                Icons.local_pharmacy,
                Colors.purple,
              ),
              const SizedBox(height: 16),
              _buildStatCard(
                'المستشفيات',
                '${stats['hospitals'] ?? 0}',
                Icons.local_hospital,
                Colors.blue,
              ),
              const SizedBox(height: 24),
              _buildStatCard(
                'سجلات التدقيق',
                '${stats['auditLogs'] ?? 0}',
                Icons.history,
                Colors.grey,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: color.withValues(alpha: 0.2),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'التقارير',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'تقرير نشاط المستخدمين',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text('آخر 7 أيام: ${_auditLogs.where((l) => l.action == AuditAction.login).length} تسجيل دخول'),
                  const SizedBox(height: 8),
                  Text('آخر 30 يوم: ${_auditLogs.where((l) => l.action == AuditAction.createPrescription).length} وصفة جديدة'),
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
                    'تقرير الأمان',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text('إجمالي السجلات: ${_auditLogs.length}'),
                  const SizedBox(height: 8),
                  Text('آخر تحديث: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditLogsTab() {
    final filteredLogs = _filterAction == null
        ? _auditLogs
        : _auditLogs.where((log) => log.action == _filterAction).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<AuditAction?>(
                  decoration: const InputDecoration(
                    labelText: 'فلترة حسب الإجراء',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  value: _filterAction,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('جميع الإجراءات'),
                    ),
                    ...AuditAction.values.map((action) {
                      return DropdownMenuItem(
                        value: action,
                        child: Text(_getActionName(action)),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() => _filterAction = value);
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const ListSkeletonLoader(itemCount: 5)
              : _buildAuditLogsList(filteredLogs),
        ),
      ],
    );
  }

  Widget _buildAuditLogsList(List<AuditLogModel> filtered) {
    if (filtered.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.history,
        title: _filterAction == null
            ? 'لا توجد سجلات'
            : 'لا توجد سجلات لهذا الإجراء',
        subtitle: _filterAction == null
            ? 'لم يتم تسجيل أي أحداث حتى الآن'
            : 'جرب اختيار إجراء آخر أو إزالة الفلترة',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAuditLogs,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final log = filtered[index];
          return _buildAuditLogCard(log);
        },
      ),
    );
  }

  Widget _buildAuditLogCard(AuditLogModel log) {
    final actionColor = _getActionColor(log.action);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: actionColor.withValues(alpha: 0.2),
          child: Icon(
            _getActionIcon(log.action),
            color: actionColor,
          ),
        ),
        title: Text(
          log.actionName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('المستخدم: ${log.userName}'),
            Text('النوع: ${log.resourceType}'),
            Text('الوقت: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(log.timestamp)}'),
            if (log.details != null) Text('التفاصيل: ${log.details}'),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Color _getActionColor(AuditAction action) {
    switch (action) {
      case AuditAction.login:
        return Colors.green;
      case AuditAction.logout:
        return Colors.orange;
      case AuditAction.createUser:
      case AuditAction.updateUser:
      case AuditAction.deleteUser:
        return Colors.blue;
      case AuditAction.createPrescription:
      case AuditAction.updatePrescription:
        return Colors.teal;
      case AuditAction.createOrder:
      case AuditAction.updateOrder:
        return Colors.indigo;
      case AuditAction.createEntity:
      case AuditAction.updateEntity:
      case AuditAction.deleteEntity:
        return Colors.purple;
      case AuditAction.systemSettingsUpdate:
        return Colors.red;
    }
  }

  IconData _getActionIcon(AuditAction action) {
    switch (action) {
      case AuditAction.login:
        return Icons.login;
      case AuditAction.logout:
        return Icons.logout;
      case AuditAction.createUser:
      case AuditAction.updateUser:
      case AuditAction.deleteUser:
        return Icons.person;
      case AuditAction.createPrescription:
      case AuditAction.updatePrescription:
        return Icons.description;
      case AuditAction.createOrder:
      case AuditAction.updateOrder:
        return Icons.shopping_cart;
      case AuditAction.createEntity:
      case AuditAction.updateEntity:
      case AuditAction.deleteEntity:
        return Icons.business;
      case AuditAction.systemSettingsUpdate:
        return Icons.settings;
    }
  }

  String _getActionName(AuditAction action) {
    switch (action) {
      case AuditAction.login:
        return 'تسجيل دخول';
      case AuditAction.logout:
        return 'تسجيل خروج';
      case AuditAction.createUser:
        return 'إنشاء مستخدم';
      case AuditAction.updateUser:
        return 'تحديث مستخدم';
      case AuditAction.deleteUser:
        return 'حذف مستخدم';
      case AuditAction.createPrescription:
        return 'إنشاء وصفة';
      case AuditAction.updatePrescription:
        return 'تحديث وصفة';
      case AuditAction.createOrder:
        return 'إنشاء طلب';
      case AuditAction.updateOrder:
        return 'تحديث طلب';
      case AuditAction.createEntity:
        return 'إنشاء كيان';
      case AuditAction.updateEntity:
        return 'تحديث كيان';
      case AuditAction.deleteEntity:
        return 'حذف كيان';
      case AuditAction.systemSettingsUpdate:
        return 'تحديث إعدادات النظام';
    }
  }

  Future<Map<String, dynamic>> _loadStatistics() async {
    try {
      final users = await _dataService.getUsers();
      final prescriptions = await _dataService.getPrescriptions();
      final orders = await _dataService.getOrders();
      final entities = await _dataService.getEntities();
      final auditLogs = await _dataService.getAuditLogs();

      return {
        'totalUsers': users.length,
        'doctors': users.where((u) => u.role == UserRole.doctor).length,
        'pharmacists': users.where((u) => u.role == UserRole.pharmacist).length,
        'patients': users.where((u) => u.role == UserRole.patient).length,
        'totalPrescriptions': prescriptions.length,
        'totalOrders': orders.length,
        'pharmacies': entities.where((e) => e.type == EntityType.pharmacy).length,
        'hospitals': entities.where((e) => e.type == EntityType.hospital).length,
        'auditLogs': auditLogs.length,
      };
    } catch (e) {
      return {};
    }
  }

  Widget _buildSettingsTab() {
    final user = AuthHelper.getCurrentUser(context);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'إعدادات النظام',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          const Text(
            'أمان الحساب الإداري',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Card(
            child: ExpansionTile(
              leading: Icon(
                Icons.fingerprint,
                color: _biometricEnabled && _userBiometricEnabled && _userBiometricAvailable
                    ? Colors.green
                    : Colors.grey,
              ),
              title: const Text('تسجيل الدخول بالبصمة (للمدير)'),
              subtitle: Text(
                !_biometricEnabled
                    ? 'المصادقة البيومترية معطلة على مستوى النظام'
                    : !_userBiometricAvailable
                        ? 'الجهاز لا يدعم أو لا توجد بصمة مسجلة بعد'
                        : _userBiometricEnabled
                            ? 'مفعلة - يمكنك استخدام البصمة لتسجيل الدخول'
                            : 'غير مفعلة - قم بتفعيلها لتسجيل الدخول بسرعة وأمان',
              ),
              trailing: (_biometricEnabled && _userBiometricAvailable)
                  ? Switch(
                      value: _userBiometricEnabled,
                      onChanged: (_) => _toggleUserBiometric(),
                    )
                  : null,
              children: [
                if (_isCheckingUserBiometric)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBiometricStatusRow(
                          'دعم الجهاز',
                          (_userBiometricStatus?['supported'] == true),
                          (_userBiometricStatus?['supported'] == true)
                              ? 'الجهاز يدعم المصادقة البيومترية ✓'
                              : 'الجهاز الحالي لا يدعم البصمة أو Face ID',
                        ),
                        const SizedBox(height: 8),
                        _buildBiometricStatusRow(
                          'البصمات المسجلة',
                          (_userBiometricStatus?['enrolled'] == true),
                          (_userBiometricStatus?['enrolled'] == true)
                              ? 'تم تسجيل بصمة في إعدادات الجهاز ✓'
                              : 'قم بتسجيل بصمة في إعدادات الجهاز قبل التفعيل',
                        ),
                        const SizedBox(height: 8),
                        _buildBiometricStatusRow(
                          'متاح للاستخدام',
                          (_userBiometricStatus?['available'] == true),
                          (_userBiometricStatus?['available'] == true)
                              ? 'يمكنك استخدام البصمة الآن'
                              : 'تأكد من تسجيل بصمة وتفعيل قفل الشاشة والصلاحيات',
                        ),
                        if (_userBiometricStatus?['message'] != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            'ملاحظات:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _userBiometricStatus?['message']?.toString() ?? '',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _testUserBiometric,
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('اختبار المصادقة الآن'),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: _checkUserBiometric,
                              icon: const Icon(Icons.refresh),
                              label: const Text('تحديث الحالة'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'خطوات التفعيل الناجح:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        _buildStep('1', 'تأكد من تسجيل بصمة في إعدادات الجهاز (FingerPrint / Face ID)'),
                        _buildStep('2', 'قم بتفعيل قفل الشاشة (PIN أو كلمة مرور أو نمط)'),
                        _buildStep('3', 'عند ظهور النافذة اضغط متابعة ثم ضع إصبعك بدون إلغاء'),
                        if (!_biometricEnabled) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.lock_open, color: Colors.orange[700]),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'ملاحظة: لن تعمل البصمة للحساب إذا كانت معطلة من إعدادات النظام أعلاه.',
                                    style: TextStyle(color: Colors.orange[700], fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.fingerprint, size: 32, color: Colors.blue),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'المصادقة البيومترية',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _biometricAvailable
                                  ? 'المصادقة البيومترية متاحة على هذا الجهاز'
                                  : 'المصادقة البيومترية غير متاحة على هذا الجهاز (Windows/Linux)',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_isLoadingSettings)
                    const Center(child: CircularProgressIndicator())
                  else
                    SwitchListTile(
                      title: const Text('تفعيل المصادقة البيومترية للنظام'),
                      subtitle: Text(
                        _biometricEnabled
                            ? 'المصادقة البيومترية مفعلة - يمكن للمستخدمين تسجيل الدخول باستخدام البصمة'
                            : 'المصادقة البيومترية معطلة - يجب تسجيل الدخول بكلمة المرور',
                      ),
                      value: _biometricEnabled && _biometricAvailable,
                      onChanged: _biometricAvailable
                          ? (value) async {
                              try {
                                await _dataService.setBiometricEnabled(
                                  value,
                                  updatedBy: user?.id,
                                );
                                await _loadSystemSettings();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        value
                                            ? 'تم تفعيل المصادقة البيومترية'
                                            : 'تم تعطيل المصادقة البيومترية',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('خطأ في تحديث الإعدادات: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            }
                          : null,
                      secondary: Icon(
                        _biometricAvailable
                            ? (_biometricEnabled
                                ? Icons.fingerprint
                                : Icons.fingerprint_outlined)
                            : Icons.fingerprint_outlined,
                        color: _biometricAvailable
                            ? (_biometricEnabled ? Colors.blue : Colors.grey)
                            : Colors.grey,
                      ),
                    ),
                  if (!_biometricAvailable) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'ملاحظة: المصادقة البيومترية متاحة فقط على Android و iOS و macOS',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'معلومات الإعدادات',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder(
                    future: _dataService.getSystemSetting('biometric_enabled') as Future<SystemSettingsModel?>,
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data != null) {
                        final setting = snapshot.data!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('آخر تحديث: ${DateFormat('yyyy-MM-dd HH:mm').format(setting.updatedAt)}'),
                            if (setting.updatedBy != null)
                              Text('تم التحديث بواسطة: ${setting.updatedBy}'),
                          ],
                        );
                      }
                      return const SizedBox.shrink();
                    },
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

