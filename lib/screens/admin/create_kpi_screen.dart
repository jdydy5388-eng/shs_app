import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/quality_models.dart';
import '../../services/data_service.dart';
import '../../utils/auth_helper.dart';

class CreateKPIScreen extends StatefulWidget {
  const CreateKPIScreen({super.key});

  @override
  State<CreateKPIScreen> createState() => _CreateKPIScreenState();
}

class _CreateKPIScreenState extends State<CreateKPIScreen> {
  final DataService _dataService = DataService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _arabicNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _targetValueController = TextEditingController();
  final _unitController = TextEditingController();

  KPICategory _selectedCategory = KPICategory.other;
  KPIType _selectedType = KPIType.count;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _arabicNameController.dispose();
    _descriptionController.dispose();
    _targetValueController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  Future<void> _saveKPI() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = AuthHelper.getCurrentUser(context);
    if (currentUser == null) return;

    final kpi = KPIModel(
      id: const Uuid().v4(),
      name: _nameController.text.trim(),
      arabicName: _arabicNameController.text.trim().isEmpty
          ? null
          : _arabicNameController.text.trim(),
      description: _descriptionController.text.trim(),
      category: _selectedCategory,
      type: _selectedType,
      targetValue: _targetValueController.text.trim().isEmpty
          ? null
          : double.tryParse(_targetValueController.text.trim()),
      unit: _unitController.text.trim().isEmpty
          ? null
          : _unitController.text.trim(),
      createdAt: DateTime.now(),
    );

    setState(() => _isSaving = true);
    try {
      await _dataService.createKPI(kpi);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إنشاء مؤشر الجودة بنجاح')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في إنشاء مؤشر الجودة: $e')),
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
        title: const Text('إضافة مؤشر جودة جديد'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم المؤشر (إنجليزي) *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value?.isEmpty ?? true
                    ? 'يرجى إدخال اسم المؤشر'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _arabicNameController,
                decoration: const InputDecoration(
                  labelText: 'اسم المؤشر (عربي)',
                  border: OutlineInputBorder(),
                ),
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
                    ? 'يرجى إدخال وصف المؤشر'
                    : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<KPICategory>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'الفئة *',
                  border: OutlineInputBorder(),
                ),
                items: KPICategory.values.map((cat) {
                  final catText = {
                    KPICategory.patientSafety: 'سلامة المرضى',
                    KPICategory.clinicalOutcomes: 'النتائج السريرية',
                    KPICategory.patientSatisfaction: 'رضا المرضى',
                    KPICategory.operationalEfficiency: 'الكفاءة التشغيلية',
                    KPICategory.financial: 'مالي',
                    KPICategory.infectionControl: 'مكافحة العدوى',
                    KPICategory.medicationSafety: 'سلامة الأدوية',
                    KPICategory.other: 'أخرى',
                  }[cat]!;
                  return DropdownMenuItem(value: cat, child: Text(catText));
                }).toList(),
                onChanged: (value) => setState(() => _selectedCategory = value!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<KPIType>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'نوع المؤشر *',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: KPIType.percentage, child: Text('نسبة مئوية')),
                  DropdownMenuItem(value: KPIType.count, child: Text('عدد')),
                  DropdownMenuItem(value: KPIType.rate, child: Text('معدل')),
                  DropdownMenuItem(value: KPIType.average, child: Text('متوسط')),
                  DropdownMenuItem(value: KPIType.time, child: Text('وقت')),
                ],
                onChanged: (value) => setState(() => _selectedType = value!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _targetValueController,
                decoration: const InputDecoration(
                  labelText: 'القيمة المستهدفة',
                  border: OutlineInputBorder(),
                  hintText: 'مثال: 95',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _unitController,
                decoration: const InputDecoration(
                  labelText: 'الوحدة',
                  border: OutlineInputBorder(),
                  hintText: 'مثال: %, عدد, يوم',
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveKPI,
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

