import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../models/medical_record_model.dart';
import '../../models/prescription_model.dart';
import '../../services/data_service.dart';
import '../../widgets/loading_widgets.dart';
import '../../widgets/status_banner.dart';
import '../../utils/ui_snackbar.dart';

class PatientDetailsScreen extends StatefulWidget {
  final UserModel patient;

  const PatientDetailsScreen({
    super.key,
    required this.patient,
  });

  @override
  State<PatientDetailsScreen> createState() => _PatientDetailsScreenState();
}

class _PatientDetailsScreenState extends State<PatientDetailsScreen>
    with SingleTickerProviderStateMixin {
  final DataService _dataService = DataService();
  late TabController _tabController;

  List<MedicalRecordModel> _medicalRecords = [];
  List<PrescriptionModel> _prescriptions = [];
  bool _isLoadingRecords = true;
  bool _isLoadingPrescriptions = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadMedicalRecords(),
      _loadPrescriptions(),
    ]);
  }

  Future<void> _loadMedicalRecords() async {
    setState(() => _isLoadingRecords = true);
    try {
      final records = await _dataService.getMedicalRecords(
        patientId: widget.patient.id,
      );
      setState(() {
        _medicalRecords = records.cast<MedicalRecordModel>();
        _isLoadingRecords = false;
      });
    } catch (e) {
      setState(() => _isLoadingRecords = false);
      if (mounted) {
        showFriendlyAuthError(context, e);
      }
    }
  }

  Future<void> _loadPrescriptions() async {
    setState(() => _isLoadingPrescriptions = true);
    try {
      final prescriptions = await _dataService.getPrescriptions(
        patientId: widget.patient.id,
      );
      setState(() {
        _prescriptions = prescriptions.cast<PrescriptionModel>();
        _isLoadingPrescriptions = false;
      });
    } catch (e) {
      setState(() => _isLoadingPrescriptions = false);
      if (mounted) {
        showFriendlyAuthError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('تفاصيل المريض: ${widget.patient.name}'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'المعلومات', icon: Icon(Icons.person)),
            Tab(text: 'السجل الصحي', icon: Icon(Icons.medical_services)),
            Tab(text: 'الوصفات', icon: Icon(Icons.description)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPatientInfoTab(),
          _buildMedicalRecordsTab(),
          _buildPrescriptionsTab(),
        ],
      ),
    );
  }

  Widget _buildPatientInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // بطاقة معلومات المريض
          Card(
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.blue.shade100,
                        child: Icon(
                          Icons.person,
                          size: 40,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.patient.name,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (widget.patient.email.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.email, size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      widget.patient.email,
                                      style: TextStyle(color: Colors.grey[700]),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  _buildInfoRow('الهاتف', widget.patient.phone, Icons.phone),
                  if (widget.patient.bloodType != null)
                    _buildInfoRow(
                      'فصيلة الدم',
                      widget.patient.bloodType!,
                      Icons.bloodtype,
                      color: Colors.red,
                    ),
                  if (widget.patient.dateOfBirth != null)
                    _buildInfoRow(
                      'تاريخ الميلاد',
                      widget.patient.dateOfBirth!,
                      Icons.calendar_today,
                    ),
                  if (widget.patient.additionalInfo?['address'] != null)
                    _buildInfoRow(
                      'العنوان',
                      widget.patient.additionalInfo!['address'].toString(),
                      Icons.location_on,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // إحصائيات سريعة
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'السجلات الطبية',
                  '${_medicalRecords.length}',
                  Icons.medical_services,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'الوصفات',
                  '${_prescriptions.length}',
                  Icons.description,
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color ?? Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
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
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicalRecordsTab() {
    if (_isLoadingRecords) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_medicalRecords.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.folder_open_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'لا توجد سجلات طبية',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMedicalRecords,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _medicalRecords.length,
        itemBuilder: (context, index) {
          final record = _medicalRecords[index];
          return _buildRecordCard(record);
        },
      ),
    );
  }

  Widget _buildRecordCard(MedicalRecordModel record) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getRecordColor(record.type).withValues(alpha: 0.2),
          child: Icon(
            _getRecordIcon(record.type),
            color: _getRecordColor(record.type),
          ),
        ),
        title: Text(
          record.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('yyyy-MM-dd').format(record.date)),
            if (record.doctorName != null)
              Text('الطبيب: ${record.doctorName}'),
            if (record.fileUrls != null && record.fileUrls!.isNotEmpty)
              Text(
                '${record.fileUrls!.length} ملف مرفق',
                style: const TextStyle(color: Colors.blue, fontSize: 12),
              ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('النوع: ${_getRecordTypeName(record.type)}'),
                const SizedBox(height: 8),
                Text('الوصف: ${record.description}'),
                if (record.fileUrls != null && record.fileUrls!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'الملفات المرفقة:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...record.fileUrls!.map((url) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.attach_file),
                          title: Text(url),
                          trailing: const Icon(Icons.open_in_new),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('فتح: $url')),
                            );
                          },
                        ),
                      )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrescriptionsTab() {
    if (_isLoadingPrescriptions) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_prescriptions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.description_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'لا توجد وصفات طبية',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPrescriptions,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _prescriptions.length,
        itemBuilder: (context, index) {
          final prescription = _prescriptions[index];
          return _buildPrescriptionCard(prescription);
        },
      ),
    );
  }

  Widget _buildPrescriptionCard(PrescriptionModel prescription) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange.withValues(alpha: 0.2),
          child: const Icon(Icons.description, color: Colors.orange),
        ),
        title: Text(
          'وصفة طبية #${prescription.id.substring(0, 8)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('yyyy-MM-dd').format(prescription.createdAt)),
            if (prescription.doctorName.isNotEmpty)
              Text('الطبيب: ${prescription.doctorName}'),
            if (prescription.medications.isNotEmpty)
              Text(
                '${prescription.medications.length} دواء',
                style: const TextStyle(color: Colors.blue, fontSize: 12),
              ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (prescription.diagnosis.isNotEmpty) ...[
                  const Text(
                    'التشخيص:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(prescription.diagnosis),
                  const SizedBox(height: 16),
                ],
                if (prescription.medications.isNotEmpty) ...[
                  const Text(
                    'الأدوية:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...prescription.medications.map((med) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          color: Colors.grey[50],
                          child: ListTile(
                            title: Text(med.name),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('الجرعة: ${med.dosage}'),
                                Text('التكرار: ${med.frequency}'),
                                Text('المدة: ${med.duration}'),
                              ],
                            ),
                            trailing: Text('${med.quantity}x'),
                          ),
                        ),
                      )),
                ],
                if (prescription.notes != null && prescription.notes!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'ملاحظات:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(prescription.notes!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getRecordIcon(RecordType type) {
    switch (type) {
      case RecordType.diagnosis:
        return Icons.medical_services;
      case RecordType.labResult:
        return Icons.science;
      case RecordType.xray:
        return Icons.broken_image;
      case RecordType.prescription:
        return Icons.description;
      case RecordType.vaccination:
        return Icons.vaccines;
      case RecordType.surgery:
        return Icons.healing;
      default:
        return Icons.note;
    }
  }

  Color _getRecordColor(RecordType type) {
    switch (type) {
      case RecordType.diagnosis:
        return Colors.blue;
      case RecordType.labResult:
        return Colors.green;
      case RecordType.xray:
        return Colors.purple;
      case RecordType.prescription:
        return Colors.orange;
      case RecordType.vaccination:
        return Colors.teal;
      case RecordType.surgery:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getRecordTypeName(RecordType type) {
    switch (type) {
      case RecordType.diagnosis:
        return 'تشخيص';
      case RecordType.labResult:
        return 'نتائج تحاليل';
      case RecordType.xray:
        return 'أشعة';
      case RecordType.prescription:
        return 'وصفة طبية';
      case RecordType.vaccination:
        return 'تطعيم';
      case RecordType.surgery:
        return 'عملية جراحية';
      default:
        return 'ملاحظة';
    }
  }
}

