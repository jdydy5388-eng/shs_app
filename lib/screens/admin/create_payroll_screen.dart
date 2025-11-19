import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/hr_models.dart';
import '../../services/data_service.dart';

class CreatePayrollScreen extends StatefulWidget {
  const CreatePayrollScreen({super.key});

  @override
  State<CreatePayrollScreen> createState() => _CreatePayrollScreenState();
}

class _CreatePayrollScreenState extends State<CreatePayrollScreen> {
  final DataService _dataService = DataService();
  final _formKey = GlobalKey<FormState>();
  final _baseSalaryController = TextEditingController();
  final _allowancesController = TextEditingController();
  final _deductionsController = TextEditingController();
  final _bonusesController = TextEditingController();
  final _overtimeController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedEmployeeId;
  DateTime _payPeriodStart = DateTime.now();
  DateTime _payPeriodEnd = DateTime.now().add(const Duration(days: 30));
  bool _isSaving = false;
  List<EmployeeModel> _employees = [];

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  @override
  void dispose() {
    _baseSalaryController.dispose();
    _allowancesController.dispose();
    _deductionsController.dispose();
    _bonusesController.dispose();
    _overtimeController.dispose();
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

  double _calculateNetSalary() {
    final base = double.tryParse(_baseSalaryController.text.trim()) ?? 0.0;
    final allowances = double.tryParse(_allowancesController.text.trim()) ?? 0.0;
    final deductions = double.tryParse(_deductionsController.text.trim()) ?? 0.0;
    final bonuses = double.tryParse(_bonusesController.text.trim()) ?? 0.0;
    final overtime = double.tryParse(_overtimeController.text.trim()) ?? 0.0;
    return base + allowances - deductions + bonuses + overtime;
  }

  Future<void> _savePayroll() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEmployeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار موظف')),
      );
      return;
    }

    final payroll = PayrollModel(
      id: const Uuid().v4(),
      employeeId: _selectedEmployeeId!,
      payPeriodStart: _payPeriodStart,
      payPeriodEnd: _payPeriodEnd,
      baseSalary: double.tryParse(_baseSalaryController.text.trim()) ?? 0.0,
      allowances: _allowancesController.text.trim().isEmpty
          ? null
          : double.tryParse(_allowancesController.text.trim()),
      deductions: _deductionsController.text.trim().isEmpty
          ? null
          : double.tryParse(_deductionsController.text.trim()),
      bonuses: _bonusesController.text.trim().isEmpty
          ? null
          : double.tryParse(_bonusesController.text.trim()),
      overtime: _overtimeController.text.trim().isEmpty
          ? null
          : double.tryParse(_overtimeController.text.trim()),
      netSalary: _calculateNetSalary(),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      createdAt: DateTime.now(),
    );

    setState(() => _isSaving = true);
    try {
      await _dataService.createPayroll(payroll);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إنشاء الراتب بنجاح')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في إنشاء الراتب: $e')),
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
        title: const Text('إضافة راتب جديد'),
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
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      title: const Text('بداية الفترة'),
                      subtitle: Text('${_payPeriodStart.year}-${_payPeriodStart.month.toString().padLeft(2, '0')}-${_payPeriodStart.day.toString().padLeft(2, '0')}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _payPeriodStart,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() => _payPeriodStart = date);
                        }
                      },
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      title: const Text('نهاية الفترة'),
                      subtitle: Text('${_payPeriodEnd.year}-${_payPeriodEnd.month.toString().padLeft(2, '0')}-${_payPeriodEnd.day.toString().padLeft(2, '0')}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _payPeriodEnd,
                          firstDate: _payPeriodStart,
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() => _payPeriodEnd = date);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _baseSalaryController,
                decoration: const InputDecoration(
                  labelText: 'الراتب الأساسي *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) => value?.isEmpty ?? true
                    ? 'يرجى إدخال الراتب الأساسي'
                    : null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _allowancesController,
                decoration: const InputDecoration(
                  labelText: 'البدلات',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _deductionsController,
                decoration: const InputDecoration(
                  labelText: 'الخصومات',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bonusesController,
                decoration: const InputDecoration(
                  labelText: 'المكافآت',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _overtimeController,
                decoration: const InputDecoration(
                  labelText: 'ساعات إضافية',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'الراتب الصافي:',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${_calculateNetSalary().toStringAsFixed(2)} ريال',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
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
                onPressed: _isSaving ? null : _savePayroll,
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

