import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/hr_models.dart';
import '../../models/user_model.dart';
import '../../services/data_service.dart';
import '../../utils/auth_helper.dart';

class CreateEmployeeScreen extends StatefulWidget {
  const CreateEmployeeScreen({super.key});

  @override
  State<CreateEmployeeScreen> createState() => _CreateEmployeeScreenState();
}

class _CreateEmployeeScreenState extends State<CreateEmployeeScreen> {
  final DataService _dataService = DataService();
  final _formKey = GlobalKey<FormState>();
  final _employeeNumberController = TextEditingController();
  final _departmentController = TextEditingController();
  final _positionController = TextEditingController();
  final _salaryController = TextEditingController();

  String? _selectedUserId;
  EmploymentType _selectedType = EmploymentType.fullTime;
  DateTime _hireDate = DateTime.now();
  bool _isLoading = false;
  bool _isSaving = false;
  List<UserModel> _users = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _employeeNumberController.dispose();
    _departmentController.dispose();
    _positionController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await _dataService.getUsers();
      setState(() {
        _users = users.cast<UserModel>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل المستخدمين: $e')),
        );
      }
    }
  }

  Future<void> _saveEmployee() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار مستخدم')),
      );
      return;
    }

    final employee = EmployeeModel(
      id: const Uuid().v4(),
      userId: _selectedUserId!,
      employeeNumber: _employeeNumberController.text.trim(),
      department: _departmentController.text.trim(),
      position: _positionController.text.trim(),
      employmentType: _selectedType,
      hireDate: _hireDate,
      salary: _salaryController.text.trim().isEmpty
          ? null
          : double.tryParse(_salaryController.text.trim()),
      createdAt: DateTime.now(),
    );

    setState(() => _isSaving = true);
    try {
      await _dataService.createEmployee(employee);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إنشاء الموظف بنجاح')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في إنشاء الموظف: $e')),
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
        title: const Text('إضافة موظف جديد'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String?>(
                      value: _selectedUserId,
                      decoration: const InputDecoration(
                        labelText: 'المستخدم *',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('اختر مستخدم')),
                        ..._users.map((u) => DropdownMenuItem(
                              value: u.id,
                              child: Text('${u.name} (${u.email})'),
                            )),
                      ],
                      onChanged: (value) => setState(() => _selectedUserId = value),
                      validator: (value) => value == null ? 'يرجى اختيار مستخدم' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _employeeNumberController,
                      decoration: const InputDecoration(
                        labelText: 'رقم الموظف *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value?.isEmpty ?? true
                          ? 'يرجى إدخال رقم الموظف'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _departmentController,
                      decoration: const InputDecoration(
                        labelText: 'القسم *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value?.isEmpty ?? true
                          ? 'يرجى إدخال القسم'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _positionController,
                      decoration: const InputDecoration(
                        labelText: 'المنصب *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value?.isEmpty ?? true
                          ? 'يرجى إدخال المنصب'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<EmploymentType>(
                      value: _selectedType,
                      decoration: const InputDecoration(
                        labelText: 'نوع التوظيف *',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: EmploymentType.fullTime, child: Text('دوام كامل')),
                        DropdownMenuItem(value: EmploymentType.partTime, child: Text('دوام جزئي')),
                        DropdownMenuItem(value: EmploymentType.contract, child: Text('عقد')),
                        DropdownMenuItem(value: EmploymentType.temporary, child: Text('مؤقت')),
                      ],
                      onChanged: (value) => setState(() => _selectedType = value!),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _salaryController,
                      decoration: const InputDecoration(
                        labelText: 'الراتب',
                        border: OutlineInputBorder(),
                        hintText: 'مثال: 5000',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: const Text('تاريخ التعيين'),
                      subtitle: Text('${_hireDate.year}-${_hireDate.month.toString().padLeft(2, '0')}-${_hireDate.day.toString().padLeft(2, '0')}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _hireDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() => _hireDate = date);
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveEmployee,
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

