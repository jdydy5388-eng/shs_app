import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/surgery_model.dart';
import '../../services/data_service.dart';
import '../../utils/auth_helper.dart';

class SurgeryDetailsScreen extends StatefulWidget {
  final SurgeryModel surgery;

  const SurgeryDetailsScreen({super.key, required this.surgery});

  @override
  State<SurgeryDetailsScreen> createState() => _SurgeryDetailsScreenState();
}

class _SurgeryDetailsScreenState extends State<SurgeryDetailsScreen>
    with SingleTickerProviderStateMixin {
  final DataService _dataService = DataService();
  late SurgeryModel _surgery;
  bool _isLoading = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _surgery = widget.surgery;
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm', 'ar');

    final statusColor = {
      SurgeryStatus.scheduled: Colors.blue,
      SurgeryStatus.inProgress: Colors.orange,
      SurgeryStatus.completed: Colors.green,
      SurgeryStatus.cancelled: Colors.red,
      SurgeryStatus.postponed: Colors.grey,
    }[_surgery.status]!;

    final statusText = {
      SurgeryStatus.scheduled: 'مجدولة',
      SurgeryStatus.inProgress: 'قيد التنفيذ',
      SurgeryStatus.completed: 'مكتملة',
      SurgeryStatus.cancelled: 'ملغاة',
      SurgeryStatus.postponed: 'مؤجلة',
    }[_surgery.status]!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل العملية الجراحية'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'المعلومات', icon: Icon(Icons.info)),
            Tab(text: 'ما قبل العملية', icon: Icon(Icons.assignment)),
            Tab(text: 'أثناء العملية', icon: Icon(Icons.medical_services)),
            Tab(text: 'ما بعد العملية', icon: Icon(Icons.check_circle)),
          ],
        ),
        actions: [
          if (_surgery.status == SurgeryStatus.scheduled)
            IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: _startSurgery,
              tooltip: 'بدء العملية',
            ),
          if (_surgery.status == SurgeryStatus.inProgress)
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: _completeSurgery,
              tooltip: 'إنهاء العملية',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildInfoTab(dateFormat, statusColor, statusText),
                _buildPreOperativeTab(),
                _buildOperativeTab(),
                _buildPostOperativeTab(),
              ],
            ),
    );
  }

  Widget _buildInfoTab(DateFormat dateFormat, Color statusColor, String statusText) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _surgery.surgeryName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('المريض: ${_surgery.patientName}'),
                          ],
                        ),
                      ),
                      Chip(
                        label: Text(statusText),
                        backgroundColor: statusColor.withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  _buildInfoRow('التاريخ المحدد', dateFormat.format(_surgery.scheduledDate)),
                  if (_surgery.startTime != null)
                    _buildInfoRow('وقت البدء', dateFormat.format(_surgery.startTime!)),
                  if (_surgery.endTime != null)
                    _buildInfoRow('وقت الانتهاء', dateFormat.format(_surgery.endTime!)),
                  if (_surgery.operationRoomName != null)
                    _buildInfoRow('غرفة العمليات', _surgery.operationRoomName!),
                  _buildInfoRow(
                    'النوع',
                    {
                      SurgeryType.elective: 'اختياري',
                      SurgeryType.emergency: 'طارئ',
                      SurgeryType.urgent: 'عاجل',
                    }[_surgery.type]!,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildTeamCard(),
          if (_surgery.diagnosis != null || _surgery.procedure != null || _surgery.notes != null) ...[
            const SizedBox(height: 16),
            _buildMedicalInfoCard(),
          ],
          if (_surgery.equipment != null && _surgery.equipment!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildEquipmentCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildTeamCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'فريق العملية',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildTeamMemberRow('الجراح الرئيسي', _surgery.surgeonName, Icons.person),
            if (_surgery.assistantSurgeonName != null)
              _buildTeamMemberRow('الجراح المساعد', _surgery.assistantSurgeonName!, Icons.person),
            if (_surgery.anesthesiologistName != null)
              _buildTeamMemberRow('طبيب التخدير', _surgery.anesthesiologistName!, Icons.local_pharmacy),
            if (_surgery.nurseNames != null && _surgery.nurseNames!.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('الممرضون:', style: TextStyle(fontWeight: FontWeight.bold)),
              ..._surgery.nurseNames!.map((name) => Padding(
                    padding: const EdgeInsets.only(left: 16, top: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.medical_services, size: 16),
                        const SizedBox(width: 8),
                        Text(name),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTeamMemberRow(String role, String name, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          SizedBox(
            width: 120,
            child: Text('$role:', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(name)),
        ],
      ),
    );
  }

  Widget _buildMedicalInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'المعلومات الطبية',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_surgery.diagnosis != null) ...[
              const Text('التشخيص:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(_surgery.diagnosis!),
              const SizedBox(height: 12),
            ],
            if (_surgery.procedure != null) ...[
              const Text('الإجراء:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(_surgery.procedure!),
              const SizedBox(height: 12),
            ],
            if (_surgery.notes != null) ...[
              const Text('ملاحظات:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(_surgery.notes!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEquipmentCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'المعدات الجراحية',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _surgery.equipment!.map((eq) {
                return Chip(
                  label: Text(eq),
                  avatar: const Icon(Icons.build, size: 18),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreOperativeTab() {
    final notes = _surgery.preOperativeNotes ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'سجل ما قبل العملية',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      if (_surgery.status == SurgeryStatus.scheduled ||
                          _surgery.status == SurgeryStatus.inProgress)
                        ElevatedButton.icon(
                          onPressed: _editPreOperativeNotes,
                          icon: const Icon(Icons.edit),
                          label: const Text('تعديل'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (notes.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('لا توجد ملاحظات مسجلة'),
                      ),
                    )
                  else
                    ...notes.entries.map((entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.key,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                entry.value.toString(),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperativeTab() {
    final notes = _surgery.operativeNotes ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'سجل العملية',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      if (_surgery.status == SurgeryStatus.inProgress)
                        ElevatedButton.icon(
                          onPressed: _editOperativeNotes,
                          icon: const Icon(Icons.edit),
                          label: const Text('تعديل'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (notes.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('لا توجد ملاحظات مسجلة'),
                      ),
                    )
                  else
                    ...notes.entries.map((entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.key,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                entry.value.toString(),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostOperativeTab() {
    final notes = _surgery.postOperativeNotes ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'سجل ما بعد العملية',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      if (_surgery.status == SurgeryStatus.completed)
                        ElevatedButton.icon(
                          onPressed: _editPostOperativeNotes,
                          icon: const Icon(Icons.edit),
                          label: const Text('تعديل'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (notes.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('لا توجد ملاحظات مسجلة'),
                      ),
                    )
                  else
                    ...notes.entries.map((entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.key,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                entry.value.toString(),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startSurgery() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('بدء العملية'),
        content: const Text('هل أنت متأكد من بدء العملية الجراحية؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('بدء'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _dataService.updateSurgery(
        _surgery.id,
        status: SurgeryStatus.inProgress,
        startTime: DateTime.now(),
      );

      setState(() {
        _surgery = SurgeryModel(
          id: _surgery.id,
          patientId: _surgery.patientId,
          patientName: _surgery.patientName,
          surgeryName: _surgery.surgeryName,
          type: _surgery.type,
          status: SurgeryStatus.inProgress,
          scheduledDate: _surgery.scheduledDate,
          startTime: DateTime.now(),
          endTime: _surgery.endTime,
          operationRoomId: _surgery.operationRoomId,
          operationRoomName: _surgery.operationRoomName,
          surgeonId: _surgery.surgeonId,
          surgeonName: _surgery.surgeonName,
          assistantSurgeonId: _surgery.assistantSurgeonId,
          assistantSurgeonName: _surgery.assistantSurgeonName,
          anesthesiologistId: _surgery.anesthesiologistId,
          anesthesiologistName: _surgery.anesthesiologistName,
          nurseIds: _surgery.nurseIds,
          nurseNames: _surgery.nurseNames,
          preOperativeNotes: _surgery.preOperativeNotes,
          operativeNotes: _surgery.operativeNotes,
          postOperativeNotes: _surgery.postOperativeNotes,
          diagnosis: _surgery.diagnosis,
          procedure: _surgery.procedure,
          notes: _surgery.notes,
          equipment: _surgery.equipment,
          createdAt: _surgery.createdAt,
          updatedAt: DateTime.now(),
        );
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم بدء العملية بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في بدء العملية: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _completeSurgery() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إنهاء العملية'),
        content: const Text('هل أنت متأكد من إنهاء العملية الجراحية؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إنهاء'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _dataService.updateSurgery(
        _surgery.id,
        status: SurgeryStatus.completed,
        endTime: DateTime.now(),
      );

      setState(() {
        _surgery = SurgeryModel(
          id: _surgery.id,
          patientId: _surgery.patientId,
          patientName: _surgery.patientName,
          surgeryName: _surgery.surgeryName,
          type: _surgery.type,
          status: SurgeryStatus.completed,
          scheduledDate: _surgery.scheduledDate,
          startTime: _surgery.startTime,
          endTime: DateTime.now(),
          operationRoomId: _surgery.operationRoomId,
          operationRoomName: _surgery.operationRoomName,
          surgeonId: _surgery.surgeonId,
          surgeonName: _surgery.surgeonName,
          assistantSurgeonId: _surgery.assistantSurgeonId,
          assistantSurgeonName: _surgery.assistantSurgeonName,
          anesthesiologistId: _surgery.anesthesiologistId,
          anesthesiologistName: _surgery.anesthesiologistName,
          nurseIds: _surgery.nurseIds,
          nurseNames: _surgery.nurseNames,
          preOperativeNotes: _surgery.preOperativeNotes,
          operativeNotes: _surgery.operativeNotes,
          postOperativeNotes: _surgery.postOperativeNotes,
          diagnosis: _surgery.diagnosis,
          procedure: _surgery.procedure,
          notes: _surgery.notes,
          equipment: _surgery.equipment,
          createdAt: _surgery.createdAt,
          updatedAt: DateTime.now(),
        );
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إنهاء العملية بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إنهاء العملية: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editPreOperativeNotes() async {
    await _showNotesEditor('ما قبل العملية', _surgery.preOperativeNotes ?? {}, (notes) async {
      await _dataService.updateSurgery(_surgery.id, preOperativeNotes: notes);
      setState(() {
        _surgery = SurgeryModel(
          id: _surgery.id,
          patientId: _surgery.patientId,
          patientName: _surgery.patientName,
          surgeryName: _surgery.surgeryName,
          type: _surgery.type,
          status: _surgery.status,
          scheduledDate: _surgery.scheduledDate,
          startTime: _surgery.startTime,
          endTime: _surgery.endTime,
          operationRoomId: _surgery.operationRoomId,
          operationRoomName: _surgery.operationRoomName,
          surgeonId: _surgery.surgeonId,
          surgeonName: _surgery.surgeonName,
          assistantSurgeonId: _surgery.assistantSurgeonId,
          assistantSurgeonName: _surgery.assistantSurgeonName,
          anesthesiologistId: _surgery.anesthesiologistId,
          anesthesiologistName: _surgery.anesthesiologistName,
          nurseIds: _surgery.nurseIds,
          nurseNames: _surgery.nurseNames,
          preOperativeNotes: notes,
          operativeNotes: _surgery.operativeNotes,
          postOperativeNotes: _surgery.postOperativeNotes,
          diagnosis: _surgery.diagnosis,
          procedure: _surgery.procedure,
          notes: _surgery.notes,
          equipment: _surgery.equipment,
          createdAt: _surgery.createdAt,
          updatedAt: DateTime.now(),
        );
      });
    });
  }

  Future<void> _editOperativeNotes() async {
    await _showNotesEditor('أثناء العملية', _surgery.operativeNotes ?? {}, (notes) async {
      await _dataService.updateSurgery(_surgery.id, operativeNotes: notes);
      setState(() {
        _surgery = SurgeryModel(
          id: _surgery.id,
          patientId: _surgery.patientId,
          patientName: _surgery.patientName,
          surgeryName: _surgery.surgeryName,
          type: _surgery.type,
          status: _surgery.status,
          scheduledDate: _surgery.scheduledDate,
          startTime: _surgery.startTime,
          endTime: _surgery.endTime,
          operationRoomId: _surgery.operationRoomId,
          operationRoomName: _surgery.operationRoomName,
          surgeonId: _surgery.surgeonId,
          surgeonName: _surgery.surgeonName,
          assistantSurgeonId: _surgery.assistantSurgeonId,
          assistantSurgeonName: _surgery.assistantSurgeonName,
          anesthesiologistId: _surgery.anesthesiologistId,
          anesthesiologistName: _surgery.anesthesiologistName,
          nurseIds: _surgery.nurseIds,
          nurseNames: _surgery.nurseNames,
          preOperativeNotes: _surgery.preOperativeNotes,
          operativeNotes: notes,
          postOperativeNotes: _surgery.postOperativeNotes,
          diagnosis: _surgery.diagnosis,
          procedure: _surgery.procedure,
          notes: _surgery.notes,
          equipment: _surgery.equipment,
          createdAt: _surgery.createdAt,
          updatedAt: DateTime.now(),
        );
      });
    });
  }

  Future<void> _editPostOperativeNotes() async {
    await _showNotesEditor('ما بعد العملية', _surgery.postOperativeNotes ?? {}, (notes) async {
      await _dataService.updateSurgery(_surgery.id, postOperativeNotes: notes);
      setState(() {
        _surgery = SurgeryModel(
          id: _surgery.id,
          patientId: _surgery.patientId,
          patientName: _surgery.patientName,
          surgeryName: _surgery.surgeryName,
          type: _surgery.type,
          status: _surgery.status,
          scheduledDate: _surgery.scheduledDate,
          startTime: _surgery.startTime,
          endTime: _surgery.endTime,
          operationRoomId: _surgery.operationRoomId,
          operationRoomName: _surgery.operationRoomName,
          surgeonId: _surgery.surgeonId,
          surgeonName: _surgery.surgeonName,
          assistantSurgeonId: _surgery.assistantSurgeonId,
          assistantSurgeonName: _surgery.assistantSurgeonName,
          anesthesiologistId: _surgery.anesthesiologistId,
          anesthesiologistName: _surgery.anesthesiologistName,
          nurseIds: _surgery.nurseIds,
          nurseNames: _surgery.nurseNames,
          preOperativeNotes: _surgery.preOperativeNotes,
          operativeNotes: _surgery.operativeNotes,
          postOperativeNotes: notes,
          diagnosis: _surgery.diagnosis,
          procedure: _surgery.procedure,
          notes: _surgery.notes,
          equipment: _surgery.equipment,
          createdAt: _surgery.createdAt,
          updatedAt: DateTime.now(),
        );
      });
    });
  }

  Future<void> _showNotesEditor(
    String title,
    Map<String, dynamic> currentNotes,
    Function(Map<String, dynamic>) onSave,
  ) async {
    final vitalSignsController = TextEditingController(
      text: currentNotes['vitalSigns']?.toString() ?? '',
    );
    final allergiesController = TextEditingController(
      text: currentNotes['allergies']?.toString() ?? '',
    );
    final medicationsController = TextEditingController(
      text: currentNotes['medications']?.toString() ?? '',
    );
    final labResultsController = TextEditingController(
      text: currentNotes['labResults']?.toString() ?? '',
    );
    final notesController = TextEditingController(
      text: currentNotes['notes']?.toString() ?? '',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('سجل $title'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: vitalSignsController,
                decoration: const InputDecoration(
                  labelText: 'العلامات الحيوية',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: allergiesController,
                decoration: const InputDecoration(
                  labelText: 'الحساسيات',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: medicationsController,
                decoration: const InputDecoration(
                  labelText: 'الأدوية الحالية',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: labResultsController,
                decoration: const InputDecoration(
                  labelText: 'نتائج الفحوصات',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات إضافية',
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
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (result != true) return;

    final notes = <String, dynamic>{};
    if (vitalSignsController.text.trim().isNotEmpty) {
      notes['vitalSigns'] = vitalSignsController.text.trim();
    }
    if (allergiesController.text.trim().isNotEmpty) {
      notes['allergies'] = allergiesController.text.trim();
    }
    if (medicationsController.text.trim().isNotEmpty) {
      notes['medications'] = medicationsController.text.trim();
    }
    if (labResultsController.text.trim().isNotEmpty) {
      notes['labResults'] = labResultsController.text.trim();
    }
    if (notesController.text.trim().isNotEmpty) {
      notes['notes'] = notesController.text.trim();
    }

    try {
      await onSave(notes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ السجل بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في الحفظ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

