import 'package:flutter/material.dart';
import '../../utils/auth_helper.dart';
import 'orders_screen.dart';
import 'inventory_screen.dart';
import 'pharmacist_settings_reports_screen.dart';
import 'hospital_pharmacy_screen.dart';
import '../auth/login_screen.dart';

class PharmacistFeature {
  const PharmacistFeature({
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

class PharmacistHomeScreen extends StatefulWidget {
  const PharmacistHomeScreen({super.key});

  @override
  State<PharmacistHomeScreen> createState() => _PharmacistHomeScreenState();
}

class _PharmacistHomeScreenState extends State<PharmacistHomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const PharmacistDashboard(),
    const OrdersScreen(),
    const InventoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة الصيدلي'),
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
            icon: Icon(Icons.shopping_cart),
            label: 'الطلبات',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: 'المخزون',
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

class PharmacistDashboard extends StatelessWidget {
  const PharmacistDashboard({super.key});

  static final List<PharmacistFeature> _features = [
    PharmacistFeature(
      title: 'صيدلية المستشفى الداخلية',
      description: 'إدارة صرف الأدوية للمرضى المقيمين في المستشفى.',
      icon: Icons.local_hospital,
      color: Colors.red,
      details: [
        'صرف الأدوية للمرضى المقيمين',
        'تتبع الأدوية المعطاة للمرضى',
        'تنبيهات مواعيد الأدوية',
        'سجل الأدوية المعطاة',
        'جدولة الأدوية حسب الوصفات الطبية',
      ],
      builder: (_) => const HospitalPharmacyScreen(),
    ),
    PharmacistFeature(
      title: 'إدارة طلبات الأدوية',
      description: 'استقبال وإدارة طلبات الأدوية من المرضى بكفاءة عالية.',
      icon: Icons.shopping_cart_outlined,
      color: Colors.blue,
      details: [
        'استقبال إشعارات فورية عند ورود طلب دواء جديد من مريض.',
        'مراجعة تفاصيل الطلب والوصفة الطبية الإلكترونية المرفقة والأدوية المطلوبة وكمياتها.',
        'تحديث حالة الطلب بشكل مستمر: قبول/رفض، قيد التجهيز، جاهز للتوصيل، تم التوصيل.',
      ],
      builder: (_) => const OrdersScreen(),
    ),
    PharmacistFeature(
      title: 'إدارة المخزون واقتراح البدائل',
      description: 'الحفاظ على دقة المخزون وتلبية احتياجات المرضى.',
      icon: Icons.inventory_2_outlined,
      color: Colors.green,
      details: [
        'تحديث كميات الأدوية المتوفرة في مخزون الصيدلية بشكل دوري.',
        'اقتراح بدائل مماثلة عند عدم توفر دواء معين تحتوي على نفس المادة الفعالة.',
        'إرسال البدائل المقترحة للمريض للموافقة عليها قبل تجهيز الطلب.',
      ],
      builder: (_) => const InventoryScreen(),
    ),
    PharmacistFeature(
      title: 'التقارير والإعدادات',
      description: 'عرض التقارير الإحصائية وتحديث بيانات الصيدلية.',
      icon: Icons.insights_outlined,
      color: Colors.purple,
      details: [
        'عرض تقارير حول أداء الصيدلية: عدد الطلبات المعالجة، الأدوية الأكثر طلباً، مستويات المخزون.',
        'تحديث الملف الشخصي للصيدلية وبيانات الاتصال الخاصة بها.',
      ],
      builder: (_) => const PharmacistSettingsReportsScreen(),
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
                    child: Icon(Icons.local_pharmacy, size: 40),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'الصيدلي',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (user?.pharmacyName != null)
                          Text('الصيدلية: ${user!.pharmacyName}'),
                        if (user?.pharmacyAddress != null)
                          Text('العنوان: ${user!.pharmacyAddress}'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'وظائف الصيدلي',
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

  Widget _buildFeatureCard(BuildContext context, PharmacistFeature feature) {
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

  Widget _buildFeatureDetail(PharmacistFeature feature, String detail) {
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

  void _openFeature(BuildContext context, PharmacistFeature feature) {
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

  final PharmacistFeature feature;

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
