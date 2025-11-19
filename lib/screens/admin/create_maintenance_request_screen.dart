import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/maintenance_models.dart';
import '../../services/data_service.dart';
import '../../utils/auth_helper.dart';

class CreateMaintenanceRequestScreen extends StatefulWidget {
  const CreateMaintenanceRequestScreen({super.key});

  @override
  State<CreateMaintenanceRequestScreen> createState() => _CreateMaintenanceRequestScreenState();
}

class _CreateMaintenanceRequestScreenState extends State<CreateMaintenanceRequestScreen> {
  final DataService _dataService = DataService();
  final _formKey = GlobalKey<FormState>();
  final _equipmentNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();

  MaintenanceRequestType _selectedType = MaintenanceRequestType.corrective;
  MaintenancePriority _selectedPriority = MaintenancePriority.medium;
  DateTime? _scheduledDate;
  bool _isSaving = false;

  @override
  void dispose() {
    _equipmentNameController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveRequest() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = AuthHelper.getCurrentUser(context);
    if (currentUser == null) return;

    final request = MaintenanceRequestModel(
      id: const Uuid().v4(),
      equipmentName: _equipmentNameController.text.trim().isEmpty
          ? null
          : _equipmentNameController.text.trim(),
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      type: _selectedType,
      priority: _selectedPriority,
      description: _descriptionController.text.trim(),
      reportedBy: currentUser.id,
      reportedByName: currentUser.name,
      reportedDate: DateTime.now(),
      scheduledDate: _scheduledDate,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      createdAt: DateTime.now(),
    );

    setState(() => _isSaving = true);
    try {
      await _dataService.createMaintenanceRequest(request);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إنشاء طلب الصيانة بنجاح')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في إنشاء طلب الصيانة: $e')),
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
        title: const Text('طلب صيانة جديد'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _equipmentNameController,
                decoration: const InputDecoration(
                  labelText: 'اسم المعدة',
                  border: OutlineInputBorder(),
                ),
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
              DropdownButtonFormField<MaintenanceRequestType>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'نوع الصيانة *',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: MaintenanceRequestType.corrective, child: Text('تصحيحية')),
                  DropdownMenuItem(value: MaintenanceRequestType.preventive, child: Text('وقائية')),
                  DropdownMenuItem(value: MaintenanceRequestType.emergency, child: Text('طارئة')),
                  DropdownMenuItem(value: MaintenanceRequestType.inspection, child: Text('فحص')),
                ],
                onChanged: (value) => setState(() => _selectedType = value!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<MaintenancePriority>(
                value: _selectedPriority,
                decoration: const InputDecoration(
                  labelText: 'الأولوية *',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: MaintenancePriority.low, child: Text('منخفضة')),
                  DropdownMenuItem(value: MaintenancePriority.medium, child: Text('متوسطة')),
                  DropdownMenuItem(value: MaintenancePriority.high, child: Text('عالية')),
                  DropdownMenuItem(value: MaintenancePriority.urgent, child: Text('عاجلة')),
                ],
                onChanged: (value) => setState(() => _selectedPriority = value!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'وصف المشكلة *',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
                validator: (value) => value?.isEmpty ?? true
                    ? 'يرجى إدخال وصف المشكلة'
                    : null,
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('تاريخ مجدول (اختياري)'),
                subtitle: Text(
                  _scheduledDate == null
                      ? 'لم يتم تحديد تاريخ'
                      : '${_scheduledDate!.year}-${_scheduledDate!.month.toString().padLeft(2, '0')}-${_scheduledDate!.day.toString().padLeft(2, '0')}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_scheduledDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _scheduledDate = null),
                      ),
                    const Icon(Icons.calendar_today),
                  ],
                ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _scheduledDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() => _scheduledDate = date);
                  }
                },
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
                onPressed: _isSaving ? null : _saveRequest,
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

