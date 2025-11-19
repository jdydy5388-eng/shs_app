import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider_local.dart';
import '../../services/data_service.dart';

class NursePatientsScreen extends StatefulWidget {
  const NursePatientsScreen({super.key});

  @override
  State<NursePatientsScreen> createState() => _NursePatientsScreenState();
}

class _NursePatientsScreenState extends State<NursePatientsScreen> {
  final DataService _dataService = DataService();
  List<UserModel> _patients = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    setState(() => _isLoading = true);
    try {
      // TODO: سيتم إضافة getNursePatients في DataService
      // سيتم جلب المرضى المقيمين في الأجنحة المخصصة للممرض
      // final patients = await _dataService.getNursePatients(nurseId: nurseId);
      
      // مؤقتاً: جلب جميع المرضى
      final allPatients = await _dataService.getPatients();
      setState(() {
        _patients = allPatients.cast<UserModel>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل المرضى: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المرضى في الأجنحة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPatients,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPatients,
              child: _buildPatientsList(),
            ),
    );
  }

  Widget _buildPatientsList() {
    if (_patients.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'لا توجد مرضى في الأجنحة المخصصة لك',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _patients.length,
      itemBuilder: (context, index) {
        final patient = _patients[index];
        return _buildPatientCard(patient);
      },
    );
  }

  Widget _buildPatientCard(UserModel patient) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ExpansionTile(
        leading: const CircleAvatar(
          child: Icon(Icons.person),
        ),
        title: Text(
          patient.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (patient.email != null) Text('البريد: ${patient.email}'),
            if (patient.phone != null) Text('الهاتف: ${patient.phone}'),
            if (patient.bloodType != null) Text('فصيلة الدم: ${patient.bloodType}'),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (patient.allergies != null && patient.allergies!.isNotEmpty) ...[
                  const Text(
                    'الحساسيات:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  ...patient.allergies!.map((allergy) => 
                    Chip(
                      label: Text(allergy),
                      backgroundColor: Colors.red.withValues(alpha: 0.2),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _viewPatientDetails(patient),
                      icon: const Icon(Icons.info),
                      label: const Text('التفاصيل'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _addNursingNote(patient),
                      icon: const Icon(Icons.note_add),
                      label: const Text('إضافة سجل'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _viewPatientDetails(UserModel patient) {
    // TODO: سيتم إضافة شاشة تفاصيل المريض
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('عرض تفاصيل: ${patient.name}')),
    );
  }

  void _addNursingNote(UserModel patient) {
    // سيتم فتح شاشة إضافة سجل تمريض
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddNursingNoteScreen(patient: patient),
      ),
    );
  }
}

class AddNursingNoteScreen extends StatefulWidget {
  final UserModel patient;
  
  const AddNursingNoteScreen({super.key, required this.patient});

  @override
  State<AddNursingNoteScreen> createState() => _AddNursingNoteScreenState();
}

class _AddNursingNoteScreenState extends State<AddNursingNoteScreen> {
  final _noteController = TextEditingController();
  final _observationsController = TextEditingController();
  final _bpController = TextEditingController();
  final _pulseController = TextEditingController();
  final _tempController = TextEditingController();
  final _respController = TextEditingController();
  final _spo2Controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _noteController.dispose();
    _observationsController.dispose();
    _bpController.dispose();
    _pulseController.dispose();
    _tempController.dispose();
    _respController.dispose();
    _spo2Controller.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final vitalSigns = <String, dynamic>{};
      if (_bpController.text.trim().isNotEmpty) {
        vitalSigns['bloodPressure'] = _bpController.text.trim();
      }
      if (_pulseController.text.trim().isNotEmpty) {
        vitalSigns['pulse'] = _pulseController.text.trim();
      }
      if (_tempController.text.trim().isNotEmpty) {
        vitalSigns['temperature'] = _tempController.text.trim();
      }
      if (_respController.text.trim().isNotEmpty) {
        vitalSigns['respiration'] = _respController.text.trim();
      }
      if (_spo2Controller.text.trim().isNotEmpty) {
        vitalSigns['spo2'] = _spo2Controller.text.trim();
      }

      // TODO: سيتم إضافة createNursingNote في DataService
      // await _dataService.createNursingNote(...);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ السجل بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في حفظ السجل: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('إضافة سجل تمريض - ${widget.patient.name}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'العلامات الحيوية',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _bpController,
                        decoration: const InputDecoration(
                          labelText: 'ضغط الدم (مثال: 120/80)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _pulseController,
                              decoration: const InputDecoration(
                                labelText: 'النبض',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: _tempController,
                              decoration: const InputDecoration(
                                labelText: 'الحرارة (°C)',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _respController,
                              decoration: const InputDecoration(
                                labelText: 'التنفس',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: _spo2Controller,
                              decoration: const InputDecoration(
                                labelText: 'الأكسجين (SpO2)',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'السجل *',
                  border: OutlineInputBorder(),
                  hintText: 'أدخل سجل التمريض...',
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'يرجى إدخال السجل';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _observationsController,
                decoration: const InputDecoration(
                  labelText: 'الملاحظات (اختياري)',
                  border: OutlineInputBorder(),
                  hintText: 'أدخل الملاحظات السريرية...',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveNote,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('حفظ السجل'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

