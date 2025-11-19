import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/hr_models.dart';
import '../../services/data_service.dart';

class CreateCertificationScreen extends StatefulWidget {
  const CreateCertificationScreen({super.key});

  @override
  State<CreateCertificationScreen> createState() => _CreateCertificationScreenState();
}

class _CreateCertificationScreenState extends State<CreateCertificationScreen> {
  final DataService _dataService = DataService();
  final _formKey = GlobalKey<FormState>();
  final _certificateNameController = TextEditingController();
  final _issuingOrganizationController = TextEditingController();
  final _certificateNumberController = TextEditingController();
  final _certificateUrlController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedEmployeeId;
  DateTime _issueDate = DateTime.now();
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 365));
  bool _isSaving = false;
  List<EmployeeModel> _employees = [];

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  @override
  void dispose() {
    _certificateNameController.dispose();
    _issuingOrganizationController.dispose();
    _certificateNumberController.dispose();
    _certificateUrlController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    try {
      final employees = await _dataService.getEmployees();
      setState(() {
        _employees = employees.cast<EmployeeModel>();
      });
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _saveCertification() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEmployeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار موظف')),
      );
      return;
    }

    final cert = CertificationModel(
      id: const Uuid().v4(),
      employeeId: _selectedEmployeeId!,
      certificateName: _certificateNameController.text.trim(),
      issuingOrganization: _issuingOrganizationController.text.trim(),
      issueDate: _issueDate,
      expiryDate: _expiryDate,
      certificateNumber: _certificateNumberController.text.trim().isEmpty
          ? null
          : _certificateNumberController.text.trim(),
      certificateUrl: _certificateUrlController.text.trim().isEmpty
          ? null
          : _certificateUrlController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      status: _expiryDate.isBefore(DateTime.now())
          ? CertificationStatus.expired
          : CertificationStatus.active,
      createdAt: DateTime.now(),
    );

    setState(() => _isSaving = true);
    try {
      await _dataService.createCertification(cert);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إنشاء الشهادة بنجاح')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في إنشاء الشهادة: $e')),
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
        title: const Text('إضافة شهادة جديدة'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String?>(
                value: _selectedEmployeeId,
                decoration: const InputDecoration(
                  labelText: 'الموظف *',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('اختر موظف')),
                  ..._employees.map((e) => DropdownMenuItem(
                        value: e.id,
                        child: Text('${e.employeeNumber} - ${e.department}'),
                      )),
                ],
                onChanged: (value) => setState(() => _selectedEmployeeId = value),
                validator: (value) => value == null ? 'يرجى اختيار موظف' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _certificateNameController,
                decoration: const InputDecoration(
                  labelText: 'اسم الشهادة *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value?.isEmpty ?? true
                    ? 'يرجى إدخال اسم الشهادة'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _issuingOrganizationController,
                decoration: const InputDecoration(
                  labelText: 'الجهة المانحة *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value?.isEmpty ?? true
                    ? 'يرجى إدخال الجهة المانحة'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _certificateNumberController,
                decoration: const InputDecoration(
                  labelText: 'رقم الشهادة',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      title: const Text('تاريخ الإصدار'),
                      subtitle: Text('${_issueDate.year}-${_issueDate.month.toString().padLeft(2, '0')}-${_issueDate.day.toString().padLeft(2, '0')}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _issueDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() {
                            _issueDate = date;
                            if (_expiryDate.isBefore(_issueDate)) {
                              _expiryDate = _issueDate.add(const Duration(days: 365));
                            }
                          });
                        }
                      },
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      title: const Text('تاريخ الانتهاء'),
                      subtitle: Text('${_expiryDate.year}-${_expiryDate.month.toString().padLeft(2, '0')}-${_expiryDate.day.toString().padLeft(2, '0')}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _expiryDate,
                          firstDate: _issueDate,
                          lastDate: DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (date != null) {
                          setState(() => _expiryDate = date);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _certificateUrlController,
                decoration: const InputDecoration(
                  labelText: 'رابط الشهادة (PDF, Image)',
                  border: OutlineInputBorder(),
                  hintText: 'https://...',
                ),
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
                onPressed: _isSaving ? null : _saveCertification,
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

