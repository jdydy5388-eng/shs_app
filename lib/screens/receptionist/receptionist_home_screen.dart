import 'package:flutter/material.dart';
import '../../utils/auth_helper.dart';
import 'receptionist_patients_screen.dart';
import 'receptionist_appointments_screen.dart';
import 'receptionist_invoices_screen.dart';
import 'receptionist_directions_screen.dart';
import '../auth/login_screen.dart';

class ReceptionistFeature {
  const ReceptionistFeature({
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

class ReceptionistHomeScreen extends StatefulWidget {
  const ReceptionistHomeScreen({super.key});

  @override
  State<ReceptionistHomeScreen> createState() => _ReceptionistHomeScreenState();
}

class _ReceptionistHomeScreenState extends State<ReceptionistHomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const ReceptionistHomeContent(),
    const ReceptionistPatientsScreen(),
    const ReceptionistAppointmentsScreen(),
    const ReceptionistInvoicesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'الرئيسية',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'المرضى',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'المواعيد',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt),
            label: 'الفواتير',
          ),
        ],
      ),
    );
  }
}

class ReceptionistHomeContent extends StatelessWidget {
  const ReceptionistHomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthHelper.getCurrentUser(context);

    final features = [
      ReceptionistFeature(
        title: 'إدارة المرضى',
        description: 'تسجيل وإدارة بيانات المرضى',
        icon: Icons.people,
        color: Colors.blue,
        details: [
          'تسجيل مرضى جدد',
          'البحث عن المرضى',
          'تحديث بيانات المرضى',
          'عرض معلومات المرضى',
        ],
        builder: (_) => const ReceptionistPatientsScreen(),
      ),
      ReceptionistFeature(
        title: 'إدارة المواعيد',
        description: 'حجز وتعديل وإلغاء المواعيد',
        icon: Icons.calendar_today,
        color: Colors.green,
        details: [
          'حجز مواعيد للمرضى',
          'تعديل المواعيد',
          'إلغاء المواعيد',
          'عرض جدول المواعيد',
          'إدارة قوائم الانتظار',
        ],
        builder: (_) => const ReceptionistAppointmentsScreen(),
      ),
      ReceptionistFeature(
        title: 'إدارة الفواتير',
        description: 'إنشاء وإدارة الفواتير والمدفوعات',
        icon: Icons.receipt,
        color: Colors.orange,
        details: [
          'إنشاء فواتير جديدة',
          'عرض الفواتير',
          'تسجيل المدفوعات',
          'طباعة الفواتير',
          'متابعة المدفوعات المعلقة',
        ],
        builder: (_) => const ReceptionistInvoicesScreen(),
      ),
      ReceptionistFeature(
        title: 'توجيه المرضى',
        description: 'مساعدة المرضى في العثور على الأقسام',
        icon: Icons.directions,
        color: Colors.purple,
        details: [
          'عرض خريطة المستشفى',
          'توجيه المرضى إلى الأقسام',
          'معلومات الاتصال بالأطباء',
          'معلومات الأقسام والخدمات',
        ],
        builder: (_) => const ReceptionistDirectionsScreen(),
      ),
    ];

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
                    backgroundColor: Colors.blue,
                    child: Icon(Icons.person, size: 40, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'مرحباً، ${user?.name ?? "موظف الاستقبال"}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text('موظف الاستقبال'),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'الوظائف المتاحة',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...features.map((feature) => _buildFeatureCard(context, feature)),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(BuildContext context, ReceptionistFeature feature) {
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
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'الميزات:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...feature.details.map((detail) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, size: 16, color: feature.color),
                          const SizedBox(width: 8),
                          Expanded(child: Text(detail)),
                        ],
                      ),
                    )),
                if (feature.hasNavigation) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: feature.builder!),
                        );
                      },
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('فتح'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: feature.color,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

