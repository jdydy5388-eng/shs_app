import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/lab_test_type_model.dart';
import '../../services/data_service.dart';

class CreateLabTestTypeScreen extends StatefulWidget {
  const CreateLabTestTypeScreen({super.key});

  @override
  State<CreateLabTestTypeScreen> createState() => _CreateLabTestTypeScreenState();
}

class _CreateLabTestTypeScreenState extends State<CreateLabTestTypeScreen> {
  final DataService _dataService = DataService();
  final Uuid _uuid = const Uuid();
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _arabicNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _durationController = TextEditingController();

  LabTestCategory _selectedCategory = LabTestCategory.other;
  LabTestPriority _selectedPriority = LabTestPriority.routine;
  bool _isActive = true;

  @override
  void dispose() {
    _nameController.dispose();
    _arabicNameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة نوع فحص جديد'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم الفحص (إنجليزي) *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value?.isEmpty ?? true ? 'يرجى إدخال اسم الفحص' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _arabicNameController,
                decoration: const InputDecoration(
                  labelText: 'اسم الفحص (عربي)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<LabTestCategory>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'الفئة *',
                  border: OutlineInputBorder(),
                ),
                items: LabTestCategory.values.map((category) {
                  final categoryText = {
                    LabTestCategory.hematology: 'أمراض الدم',
                    LabTestCategory.biochemistry: 'كيمياء حيوية',
                    LabTestCategory.microbiology: 'ميكروبيولوجيا',
                    LabTestCategory.immunology: 'مناعة',
                    LabTestCategory.pathology: 'علم الأمراض',
                    LabTestCategory.serology: 'مصلية',
                    LabTestCategory.urinalysis: 'تحليل البول',
                    LabTestCategory.other: 'أخرى',
                  }[category]!;

                  return DropdownMenuItem(
                    value: category,
                    child: Text(categoryText),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedCategory = value);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'الوصف',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'السعر *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'يرجى إدخال السعر';
                  if (double.tryParse(value!) == null) return 'يرجى إدخال رقم صحيح';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _durationController,
                decoration: const InputDecoration(
                  labelText: 'المدة المتوقعة بالدقائق',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<LabTestPriority>(
                value: _selectedPriority,
                decoration: const InputDecoration(
                  labelText: 'الأولوية الافتراضية',
                  border: OutlineInputBorder(),
                ),
                items: LabTestPriority.values.map((priority) {
                  final priorityText = {
                    LabTestPriority.routine: 'روتيني',
                    LabTestPriority.urgent: 'عاجل',
                    LabTestPriority.stat: 'فوري',
                  }[priority]!;

                  return DropdownMenuItem(
                    value: priority,
                    child: Text(priorityText),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedPriority = value);
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('نشط'),
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveTestType,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('حفظ'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveTestType() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final testType = LabTestTypeModel(
        id: _uuid.v4(),
        name: _nameController.text.trim(),
        arabicName: _arabicNameController.text.trim().isEmpty
            ? null
            : _arabicNameController.text.trim(),
        category: _selectedCategory,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        price: double.parse(_priceController.text.trim()),
        estimatedDurationMinutes: _durationController.text.trim().isEmpty
            ? null
            : int.tryParse(_durationController.text.trim()),
        defaultPriority: _selectedPriority,
        isActive: _isActive,
        createdAt: DateTime.now(),
      );

      await _dataService.createLabTestType(testType);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إضافة نوع الفحص بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إضافة نوع الفحص: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

