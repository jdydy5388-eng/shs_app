import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/data_service.dart';
import '../../widgets/loading_widgets.dart';

class ReceptionistDirectionsScreen extends StatefulWidget {
  const ReceptionistDirectionsScreen({super.key});

  @override
  State<ReceptionistDirectionsScreen> createState() => _ReceptionistDirectionsScreenState();
}

class _ReceptionistDirectionsScreenState extends State<ReceptionistDirectionsScreen> {
  final DataService _dataService = DataService();
  List<UserModel> _doctors = [];
  bool _isLoading = true;

  final Map<String, String> _departments = {
    'طب عام': 'الطابق الأول - غرفة 101-110',
    'طب الأطفال': 'الطابق الأول - غرفة 201-210',
    'طب النساء والولادة': 'الطابق الثاني - غرفة 301-310',
    'طب القلب': 'الطابق الثاني - غرفة 401-410',
    'طب العظام': 'الطابق الثالث - غرفة 501-510',
    'طب العيون': 'الطابق الثالث - غرفة 601-610',
    'طب الأنف والأذن': 'الطابق الثالث - غرفة 701-710',
    'طب الجلدية': 'الطابق الرابع - غرفة 801-810',
    'طب الأعصاب': 'الطابق الرابع - غرفة 901-910',
    'الطوارئ': 'الطابق الأرضي - المدخل الرئيسي',
    'المختبر': 'الطابق الأرضي - بجانب الطوارئ',
    'الأشعة': 'الطابق الأرضي - بجانب المختبر',
    'الصيدلية': 'الطابق الأرضي - بجانب الاستقبال',
  };

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  Future<void> _loadDoctors() async {
    setState(() => _isLoading = true);
    try {
      final doctors = await _dataService.getUsers(role: UserRole.doctor);
      setState(() {
        _doctors = doctors.cast<UserModel>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('توجيه المرضى'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'استخدم هذه الصفحة لمساعدة المرضى في العثور على الأقسام والأطباء',
                              style: TextStyle(color: Colors.blue.shade900),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'الأقسام والخدمات',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._departments.entries.map((entry) => _buildDepartmentCard(entry.key, entry.value)),
                  const SizedBox(height: 24),
                  const Text(
                    'الأطباء المتاحون',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._doctors.map((doctor) => _buildDoctorCard(doctor)),
                ],
              ),
            ),
    );
  }

  Widget _buildDepartmentCard(String department, String location) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          child: Icon(Icons.local_hospital, color: Colors.blue.shade700),
        ),
        title: Text(
          department,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(location),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
        onTap: () {
          _showDepartmentInfo(department, location);
        },
      ),
    );
  }

  Widget _buildDoctorCard(UserModel doctor) {
    final specialization = doctor.specialization ?? 'عام';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.shade100,
          child: Icon(Icons.person, color: Colors.green.shade700),
        ),
        title: Text(
          'د. ${doctor.name}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('التخصص: $specialization'),
            if (doctor.phone.isNotEmpty) Text('الهاتف: ${doctor.phone}'),
          ],
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
        onTap: () {
          _showDoctorInfo(doctor);
        },
      ),
    );
  }

  void _showDepartmentInfo(String department, String location) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(department),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الموقع: $location'),
            const SizedBox(height: 16),
            const Text(
              'يمكنك توجيه المريض إلى هذا الموقع مباشرة.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _showDoctorInfo(UserModel doctor) {
    final specialization = doctor.specialization ?? 'عام';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('د. ${doctor.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('التخصص: $specialization'),
            if (doctor.email.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('البريد: ${doctor.email}'),
            ],
            if (doctor.phone.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('الهاتف: ${doctor.phone}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }
}

