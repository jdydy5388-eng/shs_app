import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/hr_models.dart';
import '../../services/data_service.dart';
import '../../utils/auth_helper.dart';

class CreateLeaveRequestScreen extends StatefulWidget {
  const CreateLeaveRequestScreen({super.key});

  @override
  State<CreateLeaveRequestScreen> createState() => _CreateLeaveRequestScreenState();
}

class _CreateLeaveRequestScreenState extends State<CreateLeaveRequestScreen> {
  final DataService _dataService = DataService();
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedEmployeeId;
  LeaveType _selectedType = LeaveType.annual;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 1));
  bool _isSaving = false;
  List<EmployeeModel> _employees = [];

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  @override
  void dispose() {
    _reasonController.dispose();
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

  int _calculateDays() {
    return _endDate.difference(_startDate).inDays + 1;
  }

  Future<void> _saveLeaveRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEmployeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار موظف')),
      );
      return;
    }

    final leave = LeaveRequestModel(
      id: const Uuid().v4(),
      employeeId: _selectedEmployeeId!,
      type: _selectedType,
      startDate: _startDate,
      endDate: _endDate,
      days: _calculateDays(),
      reason: _reasonController.text.trim().isEmpty ? null : _reasonController.text.trim(),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      createdAt: DateTime.now(),
    );

    setState(() => _isSaving = true);
    try {
      await _dataService.createLeaveRequest(leave);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إنشاء طلب الإجازة بنجاح')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في إنشاء طلب الإجازة: $e')),
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
        title: const Text('طلب إجازة جديد'),
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
              DropdownButtonFormField<LeaveType>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'نوع الإجازة *',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: LeaveType.annual, child: Text('سنوية')),
                  DropdownMenuItem(value: LeaveType.sick, child: Text('مرضية')),
                  DropdownMenuItem(value: LeaveType.emergency, child: Text('طارئة')),
                  DropdownMenuItem(value: LeaveType.maternity, child: Text('أمومة')),
                  DropdownMenuItem(value: LeaveType.paternity, child: Text('أبوة')),
                  DropdownMenuItem(value: LeaveType.unpaid, child: Text('بدون راتب')),
                  DropdownMenuItem(value: LeaveType.other, child: Text('أخرى')),
                ],
                onChanged: (value) => setState(() => _selectedType = value!),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('تاريخ البداية *'),
                subtitle: Text('${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _startDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() {
                      _startDate = date;
                      if (_endDate.isBefore(_startDate)) {
                        _endDate = _startDate.add(const Duration(days: 1));
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                title: const Text('تاريخ النهاية *'),
                subtitle: Text('${_endDate.year}-${_endDate.month.toString().padLeft(2, '0')}-${_endDate.day.toString().padLeft(2, '0')}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _endDate,
                    firstDate: _startDate,
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() => _endDate = date);
                  }
                },
              ),
              const SizedBox(height: 8),
              Text(
                'عدد الأيام: ${_calculateDays()}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'السبب',
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
                onPressed: _isSaving ? null : _saveLeaveRequest,
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

