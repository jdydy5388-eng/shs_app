import 'package:flutter/material.dart';
import '../../utils/auth_helper.dart';
import 'manage_users_screen.dart';
import 'manage_entities_screen.dart';
import 'system_monitoring_screen.dart';

class AdminFeature {
  AdminFeature({
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

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const AdminDashboard(),
    const ManageUsersScreen(),
    const ManageEntitiesScreen(),
    const SystemMonitoringScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة التحكم الإدارية'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthHelper.signOut(context);
            },
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
            icon: Icon(Icons.people),
            label: 'المستخدمين',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.business),
            label: 'الكيانات',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assessment),
            label: 'المراقبة',
          ),
        ],
      ),
    );
  }
}

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  static final List<AdminFeature> _features = [
    AdminFeature(
      title: 'إدارة المستخدمين والحسابات',
      description: 'الصلاحيات الكاملة لإدارة حسابات النظام.',
      icon: Icons.people_outlined,
      color: Colors.blue,
      details: [
        'تسجيل الدخول الآمن: المصادقة باستخدام البصمة.',
        'إنشاء حسابات جديدة للأطباء والصيادلة.',
        'تعديل بيانات الحسابات الموجودة.',
        'تعطيل أو حذف حسابات المستخدمين.',
        'إعادة تعيين كلمات المرور أو إعدادات المصادقة البيومترية.',
      ],
      builder: (_) => const ManageUsersScreen(),
    ),
    AdminFeature(
      title: 'إدارة الكيانات المتعاقدة',
      description: 'تحديث بيانات الشركاء المتعاقدين مع النظام.',
      icon: Icons.business_outlined,
      color: Colors.green,
      details: [
        'إدارة الصيدليات والمستشفيات: إضافة، إزالة، وتحديث البيانات.',
        'معلومات الاتصال والموقع الجغرافي للكيانات.',
      ],
      builder: (_) => const ManageEntitiesScreen(),
    ),
    AdminFeature(
      title: 'مراقبة النظام والأمان',
      description: 'الحفاظ على أمان وكفاءة النظام.',
      icon: Icons.security_outlined,
      color: Colors.orange,
      details: [
        'مراقبة النظام: الاطلاع على سجلات التدقيق (Audit Logs) لتتبع جميع الأنشطة.',
        'عرض التقارير والإحصائيات: استعراض تقارير شاملة حول أداء النظام.',
        'إدارة الإعدادات العامة: التحكم في الإعدادات العامة للنظام.',
      ],
      builder: (_) => const SystemMonitoringScreen(),
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
                    backgroundColor: Colors.red,
                    child: Icon(Icons.admin_panel_settings, size: 40, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'مدير النظام',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(user?.name ?? "المدير"),
                        Text(user?.email ?? ""),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'وظائف مدير النظام',
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

  Widget _buildFeatureCard(BuildContext context, AdminFeature feature) {
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

  Widget _buildFeatureDetail(AdminFeature feature, String detail) {
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

  void _openFeature(BuildContext context, AdminFeature feature) {
    final builder = feature.builder;
    if (builder != null) {
      Navigator.push(context, MaterialPageRoute(builder: builder));
    }
  }
}

