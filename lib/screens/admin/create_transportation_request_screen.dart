import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/transportation_models.dart';
import '../../services/data_service.dart';
import '../../utils/auth_helper.dart';

class CreateTransportationRequestScreen extends StatefulWidget {
  const CreateTransportationRequestScreen({super.key});

  @override
  State<CreateTransportationRequestScreen> createState() => _CreateTransportationRequestScreenState();
}

class _CreateTransportationRequestScreenState extends State<CreateTransportationRequestScreen> {
  final DataService _dataService = DataService();
  final _formKey = GlobalKey<FormState>();
  final _patientNameController = TextEditingController();
  final _pickupLocationController = TextEditingController();
  final _dropoffLocationController = TextEditingController();
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();

  TransportationRequestType _selectedType = TransportationRequestType.pickup;
  DateTime? _scheduledDate;
  bool _isSaving = false;

  @override
  void dispose() {
    _patientNameController.dispose();
    _pickupLocationController.dispose();
    _dropoffLocationController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveRequest() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = AuthHelper.getCurrentUser(context);
    if (currentUser == null) return;

    final request = TransportationRequestModel(
      id: const Uuid().v4(),
      patientName: _patientNameController.text.trim().isEmpty
          ? null
          : _patientNameController.text.trim(),
      type: _selectedType,
      pickupLocation: _pickupLocationController.text.trim().isEmpty
          ? null
          : _pickupLocationController.text.trim(),
      dropoffLocation: _dropoffLocationController.text.trim().isEmpty
          ? null
          : _dropoffLocationController.text.trim(),
      requestedDate: DateTime.now(),
      scheduledDate: _scheduledDate,
      reason: _reasonController.text.trim().isEmpty
          ? null
          : _reasonController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      requestedBy: currentUser.id,
      requestedByName: currentUser.name,
      createdAt: DateTime.now(),
    );

    setState(() => _isSaving = true);
    try {
      await _dataService.createTransportationRequest(request);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إنشاء طلب النقل بنجاح')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في إنشاء طلب النقل: $e')),
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
        title: const Text('طلب نقل جديد'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _patientNameController,
                decoration: const InputDecoration(
                  labelText: 'اسم المريض',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<TransportationRequestType>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'نوع النقل *',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: TransportationRequestType.pickup, child: Text('استلام')),
                  DropdownMenuItem(value: TransportationRequestType.dropoff, child: Text('توصيل')),
                  DropdownMenuItem(value: TransportationRequestType.transfer, child: Text('نقل')),
                  DropdownMenuItem(value: TransportationRequestType.emergency, child: Text('طوارئ')),
                ],
                onChanged: (value) => setState(() => _selectedType = value!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pickupLocationController,
                decoration: const InputDecoration(
                  labelText: 'موقع الاستلام',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dropoffLocationController,
                decoration: const InputDecoration(
                  labelText: 'موقع التوصيل',
                  border: OutlineInputBorder(),
                ),
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
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'سبب النقل',
                  border: OutlineInputBorder(),
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

