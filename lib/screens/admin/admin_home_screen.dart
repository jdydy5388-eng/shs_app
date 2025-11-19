import 'package:flutter/material.dart';
import '../../utils/auth_helper.dart';
import 'manage_users_screen.dart';
import 'manage_entities_screen.dart';
import 'system_monitoring_screen.dart';
import 'shifts_management_screen.dart';
import 'billing_management_screen.dart';
import 'rooms_beds_management_screen.dart';
import 'surgery_management_screen.dart';
import 'medical_inventory_management_screen.dart';
import 'lab_test_types_management_screen.dart';
import 'lab_reports_screen.dart';
import '../emergency/emergency_dashboard_screen.dart';
import '../auth/login_screen.dart';

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
      
      // إعادة التوجيه إلى شاشة تسجيل الدخول وإزالة جميع الشاشات السابقة
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false, // إزالة جميع الشاشات السابقة
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
    AdminFeature(
      title: 'إدارة المناوبات',
      description: 'إنشاء وتعديل وحذف المناوبات للأطباء والتمريض.',
      icon: Icons.schedule,
      color: Colors.deepPurple,
      details: [
        'إنشاء مناوبات فردية أو متكررة',
        'عرض قوائم المناوبات حسب المستخدم أو القسم',
        'حذف أو تعديل مناوبة'
      ],
      builder: (_) => const ShiftsManagementScreen(),
    ),
    AdminFeature(
      title: 'إدارة الفواتير والمدفوعات',
      description: 'إدارة الفواتير والمدفوعات والتقارير المالية.',
      icon: Icons.receipt_long,
      color: Colors.teal,
      details: [
        'إنشاء وإدارة الفواتير للمرضى',
        'تسجيل المدفوعات (نقد، بطاقة، تحويل، تأمين)',
        'عرض التقارير المالية والإحصائيات',
        'ربط الفواتير بالتأمين الصحي',
      ],
      builder: (_) => const BillingManagementScreen(),
    ),
    AdminFeature(
      title: 'قسم الطوارئ',
      description: 'إدارة حالات الطوارئ والترياج.',
      icon: Icons.local_hospital,
      color: Colors.red,
      details: [
        'إدارة حالات الطوارئ (دخول، علاج، تحويل، إفراج)',
        'نظام الترياج (تصنيف الحالات حسب الأولوية)',
        'تتبع العلامات الحيوية',
        'سجل أحداث الطوارئ',
        'تنبيهات للحالات الحرجة',
        'إحصائيات الطوارئ وأوقات الانتظار',
      ],
      builder: (_) => const EmergencyDashboardScreen(),
    ),
    AdminFeature(
      title: 'إدارة الغرف والأسرة',
      description: 'إدارة الغرف والأسرة وحجزها للمرضى.',
      icon: Icons.bed,
      color: Colors.indigo,
      details: [
        'إدارة الغرف (عادية، عناية مركزة، عمليات، عزل)',
        'إدارة الأسرة وحالتها (متاحة، مشغولة، صيانة)',
        'حجز الأسرة للمرضى',
        'نقل المرضى بين الغرف/الأسرة',
        'تتبع مدة الإقامة',
        'تنبيهات للصيانة',
        'إحصائيات معدل الإشغال',
      ],
      builder: (_) => const RoomsBedsManagementScreen(),
    ),
    AdminFeature(
      title: 'إدارة العمليات الجراحية',
      description: 'إدارة العمليات الجراحية وجدولتها.',
      icon: Icons.medical_services,
      color: Colors.purple,
      details: [
        'جدول العمليات الجراحية',
        'حجز غرف العمليات',
        'إدارة فريق العملية (جراح، مساعد، تخدير، تمريض)',
        'سجل ما قبل العملية (Pre-operative)',
        'سجل العملية (Operative Notes)',
        'سجل ما بعد العملية (Post-operative)',
        'متابعة حالة المريض بعد العملية',
        'إدارة المعدات الجراحية',
      ],
      builder: (_) => const SurgeryManagementScreen(),
    ),
    AdminFeature(
      title: 'إدارة المستودع والمعدات',
      description: 'إدارة المستودع الطبي والمعدات والمستلزمات.',
      icon: Icons.inventory,
      color: Colors.brown,
      details: [
        'إدارة المستودع الطبي (أدوات، معدات، مستلزمات)',
        'تتبع المعدات الطبية (أجهزة، آلات)',
        'جدولة صيانة المعدات',
        'تتبع تواريخ انتهاء الصلاحية',
        'تنبيهات المخزون المنخفض',
        'طلبات الشراء (Purchase Orders)',
        'تتبع الموردين',
      ],
      builder: (_) => const MedicalInventoryManagementScreen(),
    ),
      AdminFeature(
        title: 'إدارة أنواع الفحوصات المختبرية',
        description: 'إدارة أنواع الفحوصات والأسعار والجدولة.',
        icon: Icons.science,
        color: Colors.teal,
        details: [
          'إدارة أنواع الفحوصات والأسعار',
          'جدولة الفحوصات',
          'ربط الفحوصات بالحالات المرضية',
          'تقارير مختبرية متقدمة',
          'إدارة عينات الفحوصات',
          'تنبيهات للفحوصات الحرجة',
        ],
        builder: (_) => const LabTestTypesManagementScreen(),
      ),
      AdminFeature(
        title: 'التقارير المختبرية',
        description: 'تقارير وإحصائيات الفحوصات المختبرية.',
        icon: Icons.assessment,
        color: Colors.indigo,
        details: [
          'تقارير الفحوصات حسب الفترة',
          'إحصائيات الفحوصات',
          'ربط الفحوصات بالحالات المرضية',
          'تحليل الأداء',
        ],
        builder: (_) => const LabReportsScreen(),
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

