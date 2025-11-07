import 'package:flutter/material.dart';
import '../../utils/auth_helper.dart';
import 'create_prescription_screen.dart';
import 'patients_screen.dart';
import 'appointments_tasks_screen.dart';
import 'lab_requests_screen.dart';
import 'settings_reports_screen.dart';

class DoctorFeature {
  const DoctorFeature({
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

class DoctorHomeScreen extends StatefulWidget {
  const DoctorHomeScreen({super.key});

  @override
  State<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends State<DoctorHomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DoctorDashboard(),
    const PatientsScreen(),
    const CreatePrescriptionScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة الطبيب'),
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
            label: 'المرضى',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle),
            label: 'وصفة جديدة',
          ),
        ],
      ),
    );
  }
}

class DoctorDashboard extends StatelessWidget {
  const DoctorDashboard({super.key});

  static final List<DoctorFeature> _features = [
    DoctorFeature(
      title: 'إدارة السجلات الصحية للمرضى',
      description: 'تحكم كامل في بيانات المرضى وتحليلات مدعومة بالذكاء الاصطناعي.',
      icon: Icons.folder_shared_outlined,
      color: Colors.teal,
      details: [
        'البحث عن المرضى باستخدام الاسم، رقم الهوية أو رقم الملف الطبي.',
        'عرض السجل الصحي الكامل بما يشمل التاريخ الطبي، الحساسية، الوصفات السابقة والحالية، نتائج الفحوصات والملفات المرفوعة، وملاحظات الأطباء السابقين.',
        'تحليل السجل الصحي بالذكاء الاصطناعي لاقتراح تشخيص أولي وتحديد الأنماط والمخاطر الصحية المحتملة.',
        'إضافة ملاحظات سريرية جديدة إلى سجل المريض.',
      ],
      builder: (_) => const PatientsScreen(),
    ),
    DoctorFeature(
      title: 'إدارة الوصفات الطبية الإلكترونية',
      description: 'إنشاء الوصفات، التحقق من التفاعلات الدوائية وإرسالها بأمان.',
      icon: Icons.receipt_long_outlined,
      color: Colors.indigo,
      details: [
        'إنشاء وصفة طبية جديدة باختيار المريض وتحديد الأدوية، الجرعات، وتكرار الاستخدام ومدة العلاج.',
        'التحقق الذكي من التفاعلات الدوائية بناءً على تاريخ المريض الطبي والأدوية الحالية مع تنبيهات فورية لأي مخاطر.',
        'إرسال الوصفة الإلكترونية مباشرة إلى المريض وتخزينها في قاعدة البيانات.',
      ],
      builder: (_) => const CreatePrescriptionScreen(),
    ),
    DoctorFeature(
      title: 'إدارة المواعيد والمهام',
      description: 'تنظيم جدول الطبيب ومتابعة المهام المرتبطة برعاية المرضى.',
      icon: Icons.calendar_today_outlined,
      color: Colors.deepOrange,
      details: [
        'عرض جدول المواعيد المجدولة بصيغ يومية أو أسبوعية.',
        'تحديث حالة الموعد من خلال التأكيد أو الإلغاء أو إعادة الجدولة.',
        'إدارة قائمة المهام مثل مراجعة نتائج الفحوصات الجديدة أو المتابعات المطلوبة.',
      ],
      builder: (_) => const AppointmentsTasksScreen(),
    ),
    DoctorFeature(
      title: 'طلب الفحوصات والتحاليل',
      description: 'متابعة دورة حياة طلبات الفحوصات من الإصدار وحتى المراجعة.',
      icon: Icons.biotech_outlined,
      color: Colors.purple,
      details: [
        'طلب الفحوصات المخبرية أو الإشعاعية إلكترونياً وربطها تلقائياً بسجل المريض.',
        'تلقي إشعارات فورية عند توفر النتائج ومراجعتها مباشرة ضمن النظام.',
      ],
      builder: (_) => const LabRequestsScreen(),
    ),
    DoctorFeature(
      title: 'الإعدادات والتقارير',
      description: 'تحديث البيانات الشخصية وتتبع الأداء الإحصائي للطبيب.',
      icon: Icons.insights_outlined,
      color: Colors.blueGrey,
      details: [
        'تحديث الملف الشخصي للطبيب بما في ذلك البيانات الشخصية والمهنية.',
        'عرض التقارير الإحصائية حول المرضى المعالجين، الوصفات الصادرة، ومؤشرات الأداء العامة.',
      ],
      builder: (_) => const SettingsReportsScreen(),
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
                          'د. ${user?.name ?? "الطبيب"}',
                          style: const TextStyle(
                            fontSize: 24,
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
            'وظائف الطبيب',
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

  Widget _buildFeatureCard(BuildContext context, DoctorFeature feature) {
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

  Widget _buildFeatureDetail(DoctorFeature feature, String detail) {
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

  void _openFeature(BuildContext context, DoctorFeature feature) {
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

  final DoctorFeature feature;

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

