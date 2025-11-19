import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/maintenance_models.dart';
import '../../services/data_service.dart';

class CreateEquipmentStatusScreen extends StatefulWidget {
  const CreateEquipmentStatusScreen({super.key});

  @override
  State<CreateEquipmentStatusScreen> createState() => _CreateEquipmentStatusScreenState();
}

class _CreateEquipmentStatusScreenState extends State<CreateEquipmentStatusScreen> {
  final DataService _dataService = DataService();
  final _formKey = GlobalKey<FormState>();
  final _equipmentIdController = TextEditingController();
  final _equipmentNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _currentIssuesController = TextEditingController();
  final _notesController = TextEditingController();

  EquipmentCondition _selectedCondition = EquipmentCondition.good;
  DateTime _lastMaintenanceDate = DateTime.now();
  DateTime? _nextMaintenanceDate;
  bool _isSaving = false;

  @override
  void dispose() {
    _equipmentIdController.dispose();
    _equipmentNameController.dispose();
    _locationController.dispose();
    _currentIssuesController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveEquipmentStatus() async {
    if (!_formKey.currentState!.validate()) return;

    final status = EquipmentStatusModel(
      id: const Uuid().v4(),
      equipmentId: _equipmentIdController.text.trim(),
      equipmentName: _equipmentNameController.text.trim().isEmpty
          ? null
          : _equipmentNameController.text.trim(),
      condition: _selectedCondition,
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      lastMaintenanceDate: _lastMaintenanceDate,
      nextMaintenanceDate: _nextMaintenanceDate,
      currentIssues: _currentIssuesController.text.trim().isEmpty
          ? null
          : _currentIssuesController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      createdAt: DateTime.now(),
    );

    setState(() => _isSaving = true);
    try {
      await _dataService.createEquipmentStatus(status);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إنشاء حالة المعدات بنجاح')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في إنشاء حالة المعدات: $e')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة حالة معدات جديدة'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _equipmentIdController,
                decoration: const InputDecoration(
                  labelText: 'معرف المعدة *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value?.isEmpty ?? true
                    ? 'يرجى إدخال معرف المعدة'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _equipmentNameController,
                decoration: const InputDecoration(
                  labelText: 'اسم المعدة',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<EquipmentCondition>(
                value: _selectedCondition,
                decoration: const InputDecoration(
                  labelText: 'الحالة *',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: EquipmentCondition.excellent, child: Text('ممتاز')),
                  DropdownMenuItem(value: EquipmentCondition.good, child: Text('جيد')),
                  DropdownMenuItem(value: EquipmentCondition.fair, child: Text('مقبول')),
                  DropdownMenuItem(value: EquipmentCondition.poor, child: Text('ضعيف')),
                  DropdownMenuItem(value: EquipmentCondition.critical, child: Text('حرج')),
                  DropdownMenuItem(value: EquipmentCondition.outOfService, child: Text('خارج الخدمة')),
                ],
                onChanged: (value) => setState(() => _selectedCondition = value!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'الموقع',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('تاريخ آخر صيانة *'),
                subtitle: Text('${_lastMaintenanceDate.year}-${_lastMaintenanceDate.month.toString().padLeft(2, '0')}-${_lastMaintenanceDate.day.toString().padLeft(2, '0')}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _lastMaintenanceDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() => _lastMaintenanceDate = date);
                  }
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                title: const Text('تاريخ الصيانة القادمة (اختياري)'),
                subtitle: Text(
                  _nextMaintenanceDate == null
                      ? 'لم يتم تحديد تاريخ'
                      : '${_nextMaintenanceDate!.year}-${_nextMaintenanceDate!.month.toString().padLeft(2, '0')}-${_nextMaintenanceDate!.day.toString().padLeft(2, '0')}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_nextMaintenanceDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _nextMaintenanceDate = null),
                      ),
                    const Icon(Icons.calendar_today),
                  ],
                ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _nextMaintenanceDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (date != null) {
                    setState(() => _nextMaintenanceDate = date);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _currentIssuesController,
                decoration: const InputDecoration(
                  labelText: 'المشاكل الحالية',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveEquipmentStatus,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

