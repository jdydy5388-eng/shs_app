import 'package:flutter/material.dart';
import '../../utils/auth_helper.dart';
import 'medical_records_screen.dart';
import 'prescriptions_screen.dart';
import 'orders_screen.dart';
import 'notifications_appointments_screen.dart';
import 'patient_settings_screen.dart';
import 'radiology_screen.dart';

class PatientFeature {
  const PatientFeature({
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

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const PatientDashboard(),
    const PrescriptionsScreen(),
    const MedicalRecordsScreen(),
    const OrdersScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الرئيسية - المريض'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationsAppointmentsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PatientSettingsScreen(),
                ),
              );
            },
          ),
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
            icon: Icon(Icons.home),
            label: 'الرئيسية',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.description),
            label: 'الوصفات',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.medical_information),
            label: 'السجل الصحي',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'الطلبات',
          ),
        ],
      ),
    );
  }
}

class PatientDashboard extends StatelessWidget {
  const PatientDashboard({super.key});

  static final List<PatientFeature> _features = [
    PatientFeature(
      title: 'إدارة السجل الصحي والتقارير',
      description: 'التحكم في البيانات الصحية ومشاركتها.',
      icon: Icons.folder_shared_outlined,
      color: Colors.teal,
      details: [
        'عرض جميع الوصفات الطبية الإلكترونية الصادرة من الأطباء مع تفاصيل الأدوية والجرعات.',
        'رفع التقارير الطبية ونتائج الفحوصات (صور أو ملفات PDF) مباشرة إلى السجل الصحي الموحد.',
        'مراجعة السجل الصحي الكامل: التاريخ الطبي، الحساسيات، والملاحظات السريرية.',
      ],
      builder: (_) => const MedicalRecordsScreen(),
    ),
    PatientFeature(
      title: 'إدارة طلبات الأدوية',
      description: 'الحصول على الأدوية الموصوفة بسهولة.',
      icon: Icons.shopping_cart_outlined,
      color: Colors.blue,
      details: [
        'طلب الأدوية من خلال اختيار الوصفة الطبية وتحديد الصيدلية المفضلة.',
        'تتبع حالة الطلب خطوة بخطوة: من الإرسال إلى التوصيل.',
        'الموافقة على البدائل المقترحة من الصيدلي قبل إتمام الطلب.',
      ],
      builder: (_) => const OrdersScreen(),
    ),
    PatientFeature(
      title: 'التنبيهات والمواعيد',
      description: 'الالتزام بخطة العلاج والمتابعة الصحية.',
      icon: Icons.notifications_active_outlined,
      color: Colors.orange,
      details: [
        'استقبال تنبيهات تلقائية بمواعيد تناول الجرعات الدوائية.',
        'حجز المواعيد مع الأطباء المتاحين والبحث عن الأطباء المناسبين.',
      ],
      builder: (_) => const NotificationsAppointmentsScreen(),
    ),
    PatientFeature(
      title: 'تقارير الأشعة',
      description: 'عرض تقارير وصور الأشعة المرتبطة بملفك الطبي.',
      icon: Icons.image_search,
      color: Colors.purple,
      details: [
        'عرض طلبات الأشعة الصادرة',
        'عرض تقارير الأشعة والمرفقات'
      ],
      builder: (_) => const PatientRadiologyScreen(),
    ),
    PatientFeature(
      title: 'الإعدادات الشخصية',
      description: 'تحديث البيانات وإدارة الأمان.',
      icon: Icons.settings_outlined,
      color: Colors.grey,
      details: [
        'تحديث الملف الشخصي: البيانات الشخصية ومعلومات الاتصال.',
        'إدارة الأمان: التحكم في إعدادات المصادقة البيومترية وتغيير كلمة المرور.',
      ],
      builder: (_) => const PatientSettingsScreen(),
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
                    child: Icon(Icons.person, size: 40),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'مرحباً، ${user?.name ?? "المستخدم"}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (user?.bloodType != null)
                          Text('فصيلة الدم: ${user!.bloodType}'),
                        if (user?.dateOfBirth != null)
                          Text('تاريخ الميلاد: ${user!.dateOfBirth}'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'وظائف المريض',
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

  Widget _buildFeatureCard(BuildContext context, PatientFeature feature) {
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

  Widget _buildFeatureDetail(PatientFeature feature, String detail) {
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

  void _openFeature(BuildContext context, PatientFeature feature) {
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

  final PatientFeature feature;

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
