import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/emergency_case_model.dart';
import '../../models/emergency_event_model.dart';
import '../../models/lab_request_model.dart';
import '../../models/radiology_model.dart';
import '../../models/user_model.dart';
import '../../services/data_service.dart';
import '../../utils/auth_helper.dart';
import 'emergency_events_screen.dart';

class EmergencyCaseDetailsScreen extends StatefulWidget {
  final EmergencyCaseModel emergencyCase;

  const EmergencyCaseDetailsScreen({super.key, required this.emergencyCase});

  @override
  State<EmergencyCaseDetailsScreen> createState() => _EmergencyCaseDetailsScreenState();
}

class _EmergencyCaseDetailsScreenState extends State<EmergencyCaseDetailsScreen> {
  final DataService _dataService = DataService();
  final Uuid _uuid = const Uuid();
  late EmergencyCaseModel _case;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _case = widget.emergencyCase;
  }

  Future<void> _updateStatus(EmergencyStatus newStatus) async {
    setState(() => _isLoading = true);
    try {
      await _dataService.updateEmergencyCase(
        _case.id,
        status: newStatus,
      );

      setState(() {
        _case = EmergencyCaseModel(
          id: _case.id,
          patientId: _case.patientId,
          patientName: _case.patientName,
          triageLevel: _case.triageLevel,
          status: newStatus,
          vitalSigns: _case.vitalSigns,
          symptoms: _case.symptoms,
          notes: _case.notes,
          createdAt: _case.createdAt,
          updatedAt: DateTime.now(),
        );
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث حالة الحالة بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحديث الحالة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateVitalSigns() async {
    final bpController = TextEditingController(
      text: _case.vitalSigns?['bloodPressure']?.toString() ?? '',
    );
    final pulseController = TextEditingController(
      text: _case.vitalSigns?['pulse']?.toString() ?? '',
    );
    final tempController = TextEditingController(
      text: _case.vitalSigns?['temperature']?.toString() ?? '',
    );
    final respController = TextEditingController(
      text: _case.vitalSigns?['respiration']?.toString() ?? '',
    );
    final spo2Controller = TextEditingController(
      text: _case.vitalSigns?['spo2']?.toString() ?? '',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تحديث العلامات الحيوية'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: bpController,
                decoration: const InputDecoration(
                  labelText: 'ضغط الدم',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: pulseController,
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
                      controller: tempController,
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
                      controller: respController,
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
                      controller: spo2Controller,
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (result != true) return;

    final vitalSigns = <String, dynamic>{};
    if (bpController.text.trim().isNotEmpty) {
      vitalSigns['bloodPressure'] = bpController.text.trim();
    }
    if (pulseController.text.trim().isNotEmpty) {
      vitalSigns['pulse'] = pulseController.text.trim();
    }
    if (tempController.text.trim().isNotEmpty) {
      vitalSigns['temperature'] = tempController.text.trim();
    }
    if (respController.text.trim().isNotEmpty) {
      vitalSigns['respiration'] = respController.text.trim();
    }
    if (spo2Controller.text.trim().isNotEmpty) {
      vitalSigns['spo2'] = spo2Controller.text.trim();
    }

    setState(() => _isLoading = true);
    try {
      await _dataService.updateEmergencyCase(
        _case.id,
        vitalSigns: vitalSigns.isNotEmpty ? vitalSigns : null,
      );

      setState(() {
        _case = EmergencyCaseModel(
          id: _case.id,
          patientId: _case.patientId,
          patientName: _case.patientName,
          triageLevel: _case.triageLevel,
          status: _case.status,
          vitalSigns: vitalSigns.isNotEmpty ? vitalSigns : _case.vitalSigns,
          symptoms: _case.symptoms,
          notes: _case.notes,
          createdAt: _case.createdAt,
          updatedAt: DateTime.now(),
        );
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث العلامات الحيوية بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في التحديث: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm', 'ar');
    final waitTime = DateTime.now().difference(_case.createdAt);

    final triageColor = {
      TriageLevel.red: Colors.red,
      TriageLevel.orange: Colors.orange,
      TriageLevel.yellow: Colors.yellow,
      TriageLevel.green: Colors.green,
      TriageLevel.blue: Colors.blue,
    }[_case.triageLevel]!;

    final triageText = {
      TriageLevel.red: 'حرجة',
      TriageLevel.orange: 'عاجلة',
      TriageLevel.yellow: 'متوسطة',
      TriageLevel.green: 'بسيطة',
      TriageLevel.blue: 'غير عاجلة',
    }[_case.triageLevel]!;

    final statusText = {
      EmergencyStatus.waiting: 'قيد الانتظار',
      EmergencyStatus.in_treatment: 'قيد العلاج',
      EmergencyStatus.stabilized: 'مستقرة',
      EmergencyStatus.transferred: 'منقولة',
      EmergencyStatus.discharged: 'مفرج عنها',
    }[_case.status]!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل حالة الطوارئ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => _viewEvents(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderCard(triageColor, triageText, statusText, dateFormat, waitTime),
                  const SizedBox(height: 16),
                  if (_case.vitalSigns != null && _case.vitalSigns!.isNotEmpty) ...[
                    _buildVitalSignsCard(),
                    const SizedBox(height: 16),
                  ],
                  _buildSymptomsCard(),
                  if (_case.notes != null && _case.notes!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildNotesCard(),
                  ],
                  const SizedBox(height: 16),
                  _buildActionsCard(),
                  if (_case.status == EmergencyStatus.in_treatment ||
                      _case.status == EmergencyStatus.waiting) ...[
                    const SizedBox(height: 16),
                    _buildQuickActionsCard(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard(
    Color triageColor,
    String triageText,
    String statusText,
    DateFormat dateFormat,
    Duration waitTime,
  ) {
    return Card(
      color: _case.triageLevel == TriageLevel.red
          ? Colors.red.shade50
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _case.patientName ?? 'مريض غير مسجل',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_case.patientId != null)
                      Text(
                        'رقم الحالة: ${_case.id.substring(0, 8).toUpperCase()}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                  ],
                ),
                Chip(
                  label: Text(triageText),
                  backgroundColor: triageColor.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: triageColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            Text('الحالة: $statusText'),
            Text('التاريخ: ${dateFormat.format(_case.createdAt)}'),
            if (_case.status == EmergencyStatus.waiting)
              Text(
                'مدة الانتظار: ${waitTime.inMinutes} دقيقة',
                style: TextStyle(
                  color: waitTime.inMinutes > 30 ? Colors.red : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalSignsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'العلامات الحيوية',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: _updateVitalSigns,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._case.vitalSigns!.entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key),
                      Text(
                        entry.value.toString(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildSymptomsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'الأعراض',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(_case.symptoms ?? 'لا توجد أعراض مسجلة'),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ملاحظات',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(_case.notes!),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_case.status == EmergencyStatus.waiting) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _updateStatus(EmergencyStatus.in_treatment),
                  icon: const Icon(Icons.medical_services),
                  label: const Text('بدء العلاج'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (_case.status == EmergencyStatus.in_treatment) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _updateStatus(EmergencyStatus.stabilized),
                  icon: const Icon(Icons.check_circle),
                  label: const Text('الحالة مستقرة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showTransferDialog(),
                  icon: const Icon(Icons.transfer_within_a_station),
                  label: const Text('تحويل إلى قسم آخر'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (_case.status == EmergencyStatus.stabilized ||
                _case.status == EmergencyStatus.in_treatment) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _updateStatus(EmergencyStatus.discharged),
                  icon: const Icon(Icons.exit_to_app),
                  label: const Text('إفراج'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _viewEvents() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmergencyEventsScreen(caseId: _case.id),
      ),
    );
  }

  Future<void> _showTransferDialog() async {
    final departmentController = TextEditingController();
    final notesController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تحويل الحالة'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: departmentController,
                decoration: const InputDecoration(
                  labelText: 'القسم المستهدف',
                  border: OutlineInputBorder(),
                  hintText: 'مثال: العناية المركزة، الجراحة',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات التحويل',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (departmentController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('يرجى إدخال القسم المستهدف')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('تحويل'),
          ),
        ],
      ),
    );

    if (result != true) return;

    try {
      await _dataService.updateEmergencyCase(
        _case.id,
        status: EmergencyStatus.transferred,
        notes: 'منقول إلى: ${departmentController.text.trim()}\n${notesController.text.trim()}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحويل الحالة بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في التحويل: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildQuickActionsCard() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'إجراءات سريعة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _showMedicationDialog(),
                  icon: const Icon(Icons.medication),
                  label: const Text('إعطاء دواء'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showImagingDialog(),
                  icon: const Icon(Icons.image),
                  label: const Text('طلب تصوير'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showLabRequestDialog(),
                  icon: const Icon(Icons.science),
                  label: const Text('طلب فحص مخبري'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMedicationDialog() async {
    final medicationController = TextEditingController();
    final dosageController = TextEditingController();
    final notesController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إعطاء دواء'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: medicationController,
                decoration: const InputDecoration(
                  labelText: 'اسم الدواء',
                  border: OutlineInputBorder(),
                  hintText: 'مثال: باراسيتامول',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: dosageController,
                decoration: const InputDecoration(
                  labelText: 'الجرعة',
                  border: OutlineInputBorder(),
                  hintText: 'مثال: 500 مجم',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات (اختياري)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (medicationController.text.trim().isEmpty ||
                  dosageController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('يرجى إدخال اسم الدواء والجرعة')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('تسجيل'),
          ),
        ],
      ),
    );

    if (result != true) return;

    try {
      final event = EmergencyEventModel(
        id: _uuid.v4(),
        caseId: _case.id,
        eventType: 'medication',
        details: {
          'medication': medicationController.text.trim(),
          'dosage': dosageController.text.trim(),
          'notes': notesController.text.trim(),
          'administeredBy': AuthHelper.getCurrentUser(context)?.name ?? 'غير معروف',
          'administeredAt': DateTime.now().toIso8601String(),
        },
        createdAt: DateTime.now(),
      );

      await _dataService.createEmergencyEvent(event);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تسجيل إعطاء الدواء بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تسجيل الدواء: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showImagingDialog() async {
    final typeController = TextEditingController();
    final notesController = TextEditingController();
    String selectedType = 'xray';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('طلب تصوير'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'نوع التصوير',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'xray', child: Text('أشعة سينية')),
                    DropdownMenuItem(value: 'ct', child: Text('أشعة مقطعية (CT)')),
                    DropdownMenuItem(value: 'mri', child: Text('رنين مغناطيسي (MRI)')),
                    DropdownMenuItem(value: 'ultrasound', child: Text('موجات فوق صوتية')),
                    DropdownMenuItem(value: 'other', child: Text('أخرى')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedType = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: typeController,
                  decoration: const InputDecoration(
                    labelText: 'وصف التصوير',
                    border: OutlineInputBorder(),
                    hintText: 'مثال: صدر، بطن، رأس',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (typeController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى إدخال وصف التصوير')),
                  );
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('طلب'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    try {
      // إنشاء حدث طوارئ
      final event = EmergencyEventModel(
        id: _uuid.v4(),
        caseId: _case.id,
        eventType: 'imaging',
        details: {
          'type': selectedType,
          'description': typeController.text.trim(),
          'notes': notesController.text.trim(),
          'requestedBy': AuthHelper.getCurrentUser(context)?.name ?? 'غير معروف',
          'requestedAt': DateTime.now().toIso8601String(),
        },
        createdAt: DateTime.now(),
      );

      await _dataService.createEmergencyEvent(event);

      // إنشاء طلب تصوير في النظام
      if (_case.patientId != null) {
        try {
          final radiologyRequest = RadiologyRequestModel(
            id: _uuid.v4(),
            doctorId: AuthHelper.getCurrentUser(context)?.id ?? '',
            patientId: _case.patientId!,
            patientName: _case.patientName ?? 'غير معروف',
            modality: selectedType,
            bodyPart: typeController.text.trim(),
            status: RadiologyStatus.requested,
            notes: notesController.text.trim().isEmpty
                ? 'طلب من قسم الطوارئ'
                : 'طلب من قسم الطوارئ - ${notesController.text.trim()}',
            requestedAt: DateTime.now(),
          );

          await _dataService.createRadiologyRequest(radiologyRequest);
        } catch (e) {
          debugPrint('خطأ في إنشاء طلب التصوير: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم طلب التصوير بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في طلب التصوير: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showLabRequestDialog() async {
    final testTypeController = TextEditingController();
    final notesController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('طلب فحص مخبري'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: testTypeController,
                decoration: const InputDecoration(
                  labelText: 'نوع الفحص',
                  border: OutlineInputBorder(),
                  hintText: 'مثال: فحص دم شامل، كيمياء الدم',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات (اختياري)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (testTypeController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('يرجى إدخال نوع الفحص')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('طلب'),
          ),
        ],
      ),
    );

    if (result != true) return;

    try {
      // إنشاء حدث طوارئ
      final event = EmergencyEventModel(
        id: _uuid.v4(),
        caseId: _case.id,
        eventType: 'lab_request',
        details: {
          'testType': testTypeController.text.trim(),
          'notes': notesController.text.trim(),
          'requestedBy': AuthHelper.getCurrentUser(context)?.name ?? 'غير معروف',
          'requestedAt': DateTime.now().toIso8601String(),
        },
        createdAt: DateTime.now(),
      );

      await _dataService.createEmergencyEvent(event);

      // إنشاء طلب فحص مخبري في النظام
      if (_case.patientId != null) {
        try {
          final labRequest = LabRequestModel(
            id: _uuid.v4(),
            doctorId: AuthHelper.getCurrentUser(context)?.id ?? '',
            patientId: _case.patientId!,
            patientName: _case.patientName ?? 'غير معروف',
            testType: testTypeController.text.trim(),
            status: LabRequestStatus.pending,
            notes: notesController.text.trim().isEmpty
                ? 'طلب من قسم الطوارئ'
                : 'طلب من قسم الطوارئ - ${notesController.text.trim()}',
            requestedAt: DateTime.now(),
          );

          await _dataService.createLabRequest(labRequest);
        } catch (e) {
          debugPrint('خطأ في إنشاء طلب الفحص المخبري: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم طلب الفحص المخبري بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في طلب الفحص المخبري: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

