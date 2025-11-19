import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/emergency_case_model.dart';
import '../../models/user_model.dart';
import '../../services/data_service.dart';
import '../../utils/auth_helper.dart';

class CreateEmergencyCaseScreen extends StatefulWidget {
  const CreateEmergencyCaseScreen({super.key});

  @override
  State<CreateEmergencyCaseScreen> createState() => _CreateEmergencyCaseScreenState();
}

class _CreateEmergencyCaseScreenState extends State<CreateEmergencyCaseScreen> {
  final DataService _dataService = DataService();
  final _formKey = GlobalKey<FormState>();
  final Uuid _uuid = const Uuid();

  UserModel? _selectedPatient;
  TriageLevel _triageLevel = TriageLevel.green;
  String _symptoms = '';
  String _notes = '';

  // Vital Signs
  final _bpController = TextEditingController();
  final _pulseController = TextEditingController();
  final _tempController = TextEditingController();
  final _respController = TextEditingController();
  final _spo2Controller = TextEditingController();

  @override
  void dispose() {
    _bpController.dispose();
    _pulseController.dispose();
    _tempController.dispose();
    _respController.dispose();
    _spo2Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة حالة طوارئ'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPatientSelector(),
              const SizedBox(height: 24),
              _buildTriageSection(),
              const SizedBox(height: 24),
              _buildVitalSignsSection(),
              const SizedBox(height: 24),
              _buildSymptomsSection(),
              const SizedBox(height: 24),
              _buildNotesSection(),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveCase,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('حفظ الحالة'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPatientSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'اختيار المريض (اختياري)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_selectedPatient == null)
              ElevatedButton.icon(
                onPressed: _selectPatient,
                icon: const Icon(Icons.person_add),
                label: const Text('اختر مريض'),
              )
            else
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(_selectedPatient!.name),
                subtitle: Text(_selectedPatient!.email ?? ''),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _selectedPatient = null),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTriageSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'مستوى الترياج',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            RadioListTile<TriageLevel>(
              title: const Text('حرجة (أحمر) - يتطلب تدخل فوري'),
              subtitle: const Text('حالة مهددة للحياة'),
              value: TriageLevel.red,
              groupValue: _triageLevel,
              onChanged: (value) => setState(() => _triageLevel = value!),
              activeColor: Colors.red,
            ),
            RadioListTile<TriageLevel>(
              title: const Text('عاجلة (برتقالي) - يتطلب تدخل سريع'),
              subtitle: const Text('حالة خطيرة'),
              value: TriageLevel.orange,
              groupValue: _triageLevel,
              onChanged: (value) => setState(() => _triageLevel = value!),
              activeColor: Colors.orange,
            ),
            RadioListTile<TriageLevel>(
              title: const Text('متوسطة (أصفر) - يحتاج متابعة'),
              subtitle: const Text('حالة متوسطة'),
              value: TriageLevel.yellow,
              groupValue: _triageLevel,
              onChanged: (value) => setState(() => _triageLevel = value!),
              activeColor: Colors.yellow.shade700,
            ),
            RadioListTile<TriageLevel>(
              title: const Text('بسيطة (أخضر) - غير عاجلة'),
              subtitle: const Text('حالة بسيطة'),
              value: TriageLevel.green,
              groupValue: _triageLevel,
              onChanged: (value) => setState(() => _triageLevel = value!),
              activeColor: Colors.green,
            ),
            RadioListTile<TriageLevel>(
              title: const Text('غير عاجلة (أزرق) - يمكن الانتظار'),
              subtitle: const Text('حالة غير طارئة'),
              value: TriageLevel.blue,
              groupValue: _triageLevel,
              onChanged: (value) => setState(() => _triageLevel = value!),
              activeColor: Colors.blue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalSignsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'العلامات الحيوية (اختياري)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bpController,
              decoration: const InputDecoration(
                labelText: 'ضغط الدم (مثال: 120/80)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.favorite),
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
    );
  }

  Widget _buildSymptomsSection() {
    return TextFormField(
      decoration: const InputDecoration(
        labelText: 'الأعراض',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.medical_services),
        hintText: 'أدخل وصف الأعراض...',
      ),
      maxLines: 3,
      onChanged: (value) => _symptoms = value,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'يرجى إدخال الأعراض';
        }
        return null;
      },
    );
  }

  Widget _buildNotesSection() {
    return TextField(
      decoration: const InputDecoration(
        labelText: 'ملاحظات إضافية (اختياري)',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.note),
      ),
      maxLines: 3,
      onChanged: (value) => _notes = value,
    );
  }

  Future<void> _selectPatient() async {
    try {
      final patients = await _dataService.getPatients();
      final patientList = patients.cast<UserModel>();

      if (!mounted) return;
      final selected = await showDialog<UserModel>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('اختر مريض'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: patientList.length,
              itemBuilder: (context, index) {
                final patient = patientList[index];
                return ListTile(
                  title: Text(patient.name),
                  subtitle: Text(patient.email ?? ''),
                  onTap: () => Navigator.pop(context, patient),
                );
              },
            ),
          ),
        ),
      );

      if (selected != null) {
        setState(() => _selectedPatient = selected);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل المرضى: $e')),
        );
      }
    }
  }

  Future<void> _saveCase() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      Map<String, dynamic>? vitalSigns;
      if (_bpController.text.trim().isNotEmpty ||
          _pulseController.text.trim().isNotEmpty ||
          _tempController.text.trim().isNotEmpty ||
          _respController.text.trim().isNotEmpty ||
          _spo2Controller.text.trim().isNotEmpty) {
        vitalSigns = {};
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
      }

      final emergencyCase = EmergencyCaseModel(
        id: _uuid.v4(),
        patientId: _selectedPatient?.id,
        patientName: _selectedPatient?.name,
        triageLevel: _triageLevel,
        status: EmergencyStatus.waiting,
        vitalSigns: vitalSigns,
        symptoms: _symptoms.trim(),
        notes: _notes.trim().isEmpty ? null : _notes.trim(),
        createdAt: DateTime.now(),
      );

      await _dataService.createEmergencyCase(emergencyCase);

      // إنشاء حدث دخول
      try {
        final event = EmergencyEventModel(
          id: _uuid.v4(),
          caseId: emergencyCase.id,
          eventType: 'intake',
          details: {
            'triageLevel': _triageLevel.toString().split('.').last,
            'symptoms': _symptoms,
          },
          createdAt: DateTime.now(),
        );
        await _dataService.createEmergencyEvent(event);
      } catch (e) {
        debugPrint('خطأ في إنشاء حدث: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إضافة الحالة بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إضافة الحالة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

