import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/maintenance_models.dart';
import '../../services/data_service.dart';

class CreateScheduledMaintenanceScreen extends StatefulWidget {
  const CreateScheduledMaintenanceScreen({super.key});

  @override
  State<CreateScheduledMaintenanceScreen> createState() => _CreateScheduledMaintenanceScreenState();
}

class _CreateScheduledMaintenanceScreenState extends State<CreateScheduledMaintenanceScreen> {
  final DataService _dataService = DataService();
  final _formKey = GlobalKey<FormState>();
  final _equipmentIdController = TextEditingController();
  final _equipmentNameController = TextEditingController();
  final _maintenanceTypeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _intervalDaysController = TextEditingController();
  final _notesController = TextEditingController();

  ScheduledMaintenanceFrequency _selectedFrequency = ScheduledMaintenanceFrequency.monthly;
  DateTime _nextDueDate = DateTime.now().add(const Duration(days: 30));
  bool _isSaving = false;

  @override
  void dispose() {
    _equipmentIdController.dispose();
    _equipmentNameController.dispose();
    _maintenanceTypeController.dispose();
    _descriptionController.dispose();
    _intervalDaysController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveScheduledMaintenance() async {
    if (!_formKey.currentState!.validate()) return;

    final maintenance = ScheduledMaintenanceModel(
      id: const Uuid().v4(),
      equipmentId: _equipmentIdController.text.trim(),
      equipmentName: _equipmentNameController.text.trim().isEmpty
          ? null
          : _equipmentNameController.text.trim(),
      maintenanceType: _maintenanceTypeController.text.trim(),
      description: _descriptionController.text.trim(),
      frequency: _selectedFrequency,
      intervalDays: _selectedFrequency == ScheduledMaintenanceFrequency.custom
          ? int.tryParse(_intervalDaysController.text.trim())
          : null,
      nextDueDate: _nextDueDate,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      createdAt: DateTime.now(),
    );

    setState(() => _isSaving = true);
    try {
      await _dataService.createScheduledMaintenance(maintenance);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم جدولة الصيانة بنجاح')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في جدولة الصيانة: $e')),
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
        title: const Text('جدولة صيانة دورية'),
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
              TextFormField(
                controller: _maintenanceTypeController,
                decoration: const InputDecoration(
                  labelText: 'نوع الصيانة *',
                  border: OutlineInputBorder(),
                  hintText: 'مثال: تنظيف، فحص، استبدال',
                ),
                validator: (value) => value?.isEmpty ?? true
                    ? 'يرجى إدخال نوع الصيانة'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'الوصف *',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) => value?.isEmpty ?? true
                    ? 'يرجى إدخال الوصف'
                    : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ScheduledMaintenanceFrequency>(
                value: _selectedFrequency,
                decoration: const InputDecoration(
                  labelText: 'التكرار *',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: ScheduledMaintenanceFrequency.daily, child: Text('يومي')),
                  DropdownMenuItem(value: ScheduledMaintenanceFrequency.weekly, child: Text('أسبوعي')),
                  DropdownMenuItem(value: ScheduledMaintenanceFrequency.monthly, child: Text('شهري')),
                  DropdownMenuItem(value: ScheduledMaintenanceFrequency.quarterly, child: Text('ربع سنوي')),
                  DropdownMenuItem(value: ScheduledMaintenanceFrequency.semiAnnual, child: Text('نصف سنوي')),
                  DropdownMenuItem(value: ScheduledMaintenanceFrequency.annual, child: Text('سنوي')),
                  DropdownMenuItem(value: ScheduledMaintenanceFrequency.custom, child: Text('مخصص')),
                ],
                onChanged: (value) => setState(() => _selectedFrequency = value!),
              ),
              if (_selectedFrequency == ScheduledMaintenanceFrequency.custom) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _intervalDaysController,
                  decoration: const InputDecoration(
                    labelText: 'عدد الأيام *',
                    border: OutlineInputBorder(),
                    hintText: 'مثال: 45',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (_selectedFrequency == ScheduledMaintenanceFrequency.custom &&
                        (value?.isEmpty ?? true)) {
                      return 'يرجى إدخال عدد الأيام';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 16),
              ListTile(
                title: const Text('تاريخ الاستحقاق القادم *'),
                subtitle: Text('${_nextDueDate.year}-${_nextDueDate.month.toString().padLeft(2, '0')}-${_nextDueDate.day.toString().padLeft(2, '0')}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _nextDueDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (date != null) {
                    setState(() => _nextDueDate = date);
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
                onPressed: _isSaving ? null : _saveScheduledMaintenance,
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

