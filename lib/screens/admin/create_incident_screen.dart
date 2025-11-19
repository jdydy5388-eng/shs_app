import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/quality_models.dart';
import '../../services/data_service.dart';
import '../../utils/auth_helper.dart';

class CreateIncidentScreen extends StatefulWidget {
  const CreateIncidentScreen({super.key});

  @override
  State<CreateIncidentScreen> createState() => _CreateIncidentScreenState();
}

class _CreateIncidentScreenState extends State<CreateIncidentScreen> {
  final DataService _dataService = DataService();
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();

  IncidentType _selectedType = IncidentType.other;
  IncidentSeverity _selectedSeverity = IncidentSeverity.medium;
  DateTime _incidentDate = DateTime.now();
  bool _isSaving = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _saveIncident() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = AuthHelper.getCurrentUser(context);
    if (currentUser == null) return;

    final incident = MedicalIncidentModel(
      id: const Uuid().v4(),
      type: _selectedType,
      severity: _selectedSeverity,
      description: _descriptionController.text.trim(),
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      incidentDate: _incidentDate,
      reportedDate: DateTime.now(),
      reportedBy: currentUser.id,
      reportedByName: currentUser.name,
      createdAt: DateTime.now(),
    );

    setState(() => _isSaving = true);
    try {
      await _dataService.createMedicalIncident(incident);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إنشاء الحادث بنجاح')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في إنشاء الحادث: $e')),
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
        title: const Text('إضافة حادث طبي'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<IncidentType>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'نوع الحادث *',
                  border: OutlineInputBorder(),
                ),
                items: IncidentType.values.map((type) {
                  final typeText = {
                    IncidentType.medicationError: 'خطأ دوائي',
                    IncidentType.fall: 'سقوط',
                    IncidentType.infection: 'عدوى',
                    IncidentType.equipmentFailure: 'عطل معدات',
                    IncidentType.procedureError: 'خطأ في الإجراء',
                    IncidentType.documentationError: 'خطأ في التوثيق',
                    IncidentType.communicationError: 'خطأ في التواصل',
                    IncidentType.other: 'أخرى',
                  }[type]!;
                  return DropdownMenuItem(value: type, child: Text(typeText));
                }).toList(),
                onChanged: (value) => setState(() => _selectedType = value!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<IncidentSeverity>(
                value: _selectedSeverity,
                decoration: const InputDecoration(
                  labelText: 'خطورة الحادث *',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: IncidentSeverity.low, child: Text('منخفضة')),
                  DropdownMenuItem(value: IncidentSeverity.medium, child: Text('متوسطة')),
                  DropdownMenuItem(value: IncidentSeverity.high, child: Text('عالية')),
                  DropdownMenuItem(value: IncidentSeverity.critical, child: Text('حرجة')),
                ],
                onChanged: (value) => setState(() => _selectedSeverity = value!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'وصف الحادث *',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
                validator: (value) => value?.isEmpty ?? true
                    ? 'يرجى إدخال وصف الحادث'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'موقع الحادث',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveIncident,
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

