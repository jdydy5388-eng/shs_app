import 'package:flutter/material.dart';
import '../../utils/auth_helper.dart';
import 'lab_technician_requests_screen.dart';
import 'lab_technician_settings_screen.dart';
import 'lab_critical_alerts_screen.dart';
import '../auth/login_screen.dart';

class LabTechnicianFeature {
  const LabTechnicianFeature({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.details,
    this.builder,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final List<String> details;
  final WidgetBuilder? builder;

  bool get hasNavigation => builder != null;
}

class LabTechnicianHomeScreen extends StatefulWidget {
  const LabTechnicianHomeScreen({super.key});

  @override
  State<LabTechnicianHomeScreen> createState() => _LabTechnicianHomeScreenState();
}

class _LabTechnicianHomeScreenState extends State<LabTechnicianHomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const LabTechnicianDashboard(),
    const LabTechnicianRequestsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة فني المختبر'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'تسجيل الخروج',
            onPressed: () => _showLogoutConfirmation(context),
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'الرئيسية',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.science),
            label: 'طلبات الفحوصات',
          ),
        ],
      ),
    );
  }

  Future<void> _showLogoutConfirmation(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 12),
            Text('تأكيد تسجيل الخروج'),
          ],
        ),
        content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج؟'),
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
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;
    
    try {
      await AuthHelper.signOut(context);
      if (!mounted) return;
      
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تسجيل الخروج بنجاح'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في تسجيل الخروج: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class LabTechnicianDashboard extends StatelessWidget {
  const LabTechnicianDashboard({super.key});

  static final List<LabTechnicianFeature> _features = [
    LabTechnicianFeature(
      title: 'إدارة طلبات الفحوصات',
      description: 'استقبال وإدارة طلبات الفحوصات من الأطباء بكفاءة عالية.',
      icon: Icons.science_outlined,
      color: Colors.blue,
      details: [
        'استقبال إشعارات فورية عند ورود طلب فحص جديد من طبيب.',
        'مراجعة تفاصيل الطلب ونوع الفحص المطلوب والملاحظات.',
        'تحديث حالة الطلب: قيد الانتظار، قيد التنفيذ، مكتملة.',
        'إضافة نتائج الفحوصات والمرفقات عند اكتمال العمل.',
      ],
      builder: (_) => const LabTechnicianRequestsScreen(),
    ),
    LabTechnicianFeature(
      title: 'التقارير والإعدادات',
      description: 'عرض التقارير الإحصائية وتحديث بيانات المختبر.',
      icon: Icons.insights_outlined,
      color: Colors.purple,
      details: [
        'عرض تقارير حول أداء المختبر: عدد الطلبات المعالجة، أنواع الفحوصات الأكثر طلباً.',
        'تحديث الملف الشخصي لفني المختبر وبيانات الاتصال.',
      ],
      builder: (_) => const LabTechnicianSettingsScreen(),
    ),
    LabTechnicianFeature(
      title: 'تنبيهات الفحوصات الحرجة',
      description: 'مراقبة الفحوصات الحرجة التي تحتاج مراجعة فورية.',
      icon: Icons.warning,
      color: Colors.red,
      details: [
        'عرض الفحوصات الحرجة التي تحتاج مراجعة فورية',
        'تنبيهات تلقائية للفحوصات الحرجة',
        'متابعة الفحوصات العاجلة',
      ],
      builder: (_) => const LabCriticalAlertsScreen(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final user = AuthHelper.getCurrentUser(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 40,
                    child: Icon(Icons.science, size: 40),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'فني المختبر',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (user?.email != null)
                          Text('البريد: ${user!.email}'),
                        if (user?.phone != null)
                          Text('الهاتف: ${user!.phone}'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'وظائف فني المختبر',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ..._features.map((feature) => _buildFeatureCard(context, feature)),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(BuildContext context, LabTechnicianFeature feature) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: feature.color.withValues(alpha: 0.12),
          child: Icon(feature.icon, color: feature.color),
        ),
        title: Text(
          feature.title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(feature.description),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          ...feature.details.map((detail) => _buildFeatureDetail(feature, detail)),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: () => _openFeature(context, feature),
              icon: Icon(
                feature.hasNavigation ? Icons.open_in_new : Icons.read_more,
              ),
              label: Text(feature.hasNavigation ? 'بدء الاستخدام' : 'عرض التفاصيل'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureDetail(LabTechnicianFeature feature, String detail) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 4),
            child: Icon(
              Icons.check_circle_outline,
              size: 20,
              color: feature.color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(detail),
          ),
        ],
      ),
    );
  }

  void _openFeature(BuildContext context, LabTechnicianFeature feature) {
    final builder = feature.builder;
    if (builder != null) {
      Navigator.push(context, MaterialPageRoute(builder: builder));
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FeatureDetailsScreen(feature: feature),
        ),
      );
    }
  }
}

class FeatureDetailsScreen extends StatelessWidget {
  const FeatureDetailsScreen({super.key, required this.feature});

  final LabTechnicianFeature feature;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(feature.title),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            feature.description,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          ...feature.details.map(
            (detail) => ListTile(
              leading: Icon(Icons.check_circle_outline, color: feature.color),
              title: Text(detail),
            ),
          ),
        ],
      ),
    );
  }
}

