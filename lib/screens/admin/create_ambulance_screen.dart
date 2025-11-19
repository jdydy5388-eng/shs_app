import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/transportation_models.dart';
import '../../services/data_service.dart';

class CreateAmbulanceScreen extends StatefulWidget {
  const CreateAmbulanceScreen({super.key});

  @override
  State<CreateAmbulanceScreen> createState() => _CreateAmbulanceScreenState();
}

class _CreateAmbulanceScreenState extends State<CreateAmbulanceScreen> {
  final DataService _dataService = DataService();
  final _formKey = GlobalKey<FormState>();
  final _vehicleNumberController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _locationController = TextEditingController();
  final _equipmentController = TextEditingController();
  final _notesController = TextEditingController();

  AmbulanceType _selectedType = AmbulanceType.basic;
  AmbulanceStatus _selectedStatus = AmbulanceStatus.available;
  bool _isSaving = false;

  @override
  void dispose() {
    _vehicleNumberController.dispose();
    _vehicleModelController.dispose();
    _locationController.dispose();
    _equipmentController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveAmbulance() async {
    if (!_formKey.currentState!.validate()) return;

    final ambulance = AmbulanceModel(
      id: const Uuid().v4(),
      vehicleNumber: _vehicleNumberController.text.trim(),
      vehicleModel: _vehicleModelController.text.trim().isEmpty
          ? null
          : _vehicleModelController.text.trim(),
      type: _selectedType,
      status: _selectedStatus,
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      equipment: _equipmentController.text.trim().isEmpty
          ? null
          : _equipmentController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      createdAt: DateTime.now(),
    );

    setState(() => _isSaving = true);
    try {
      await _dataService.createAmbulance(ambulance);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إنشاء سيارة الإسعاف بنجاح')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في إنشاء سيارة الإسعاف: $e')),
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
        title: const Text('إضافة سيارة إسعاف جديدة'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _vehicleNumberController,
                decoration: const InputDecoration(
                  labelText: 'رقم المركبة *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value?.isEmpty ?? true
                    ? 'يرجى إدخال رقم المركبة'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _vehicleModelController,
                decoration: const InputDecoration(
                  labelText: 'موديل المركبة',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<AmbulanceType>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'نوع الإسعاف *',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: AmbulanceType.basic, child: Text('أساسي')),
                  DropdownMenuItem(value: AmbulanceType.advanced, child: Text('متقدم')),
                  DropdownMenuItem(value: AmbulanceType.critical, child: Text('حرج')),
                ],
                onChanged: (value) => setState(() => _selectedType = value!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<AmbulanceStatus>(
                value: _selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'الحالة *',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: AmbulanceStatus.available, child: Text('متاحة')),
                  DropdownMenuItem(value: AmbulanceStatus.onDuty, child: Text('في الخدمة')),
                  DropdownMenuItem(value: AmbulanceStatus.maintenance, child: Text('صيانة')),
                  DropdownMenuItem(value: AmbulanceStatus.outOfService, child: Text('خارج الخدمة')),
                ],
                onChanged: (value) => setState(() => _selectedStatus = value!),
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
              TextFormField(
                controller: _equipmentController,
                decoration: const InputDecoration(
                  labelText: 'المعدات المتوفرة',
                  border: OutlineInputBorder(),
                  hintText: 'مثال: جهاز تنفس، أكسجين، إلخ',
                ),
                maxLines: 2,
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
                onPressed: _isSaving ? null : _saveAmbulance,
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

