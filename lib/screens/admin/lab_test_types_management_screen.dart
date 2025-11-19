import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../models/lab_test_type_model.dart';
import '../../services/data_service.dart';
import 'create_lab_test_type_screen.dart';

class LabTestTypesManagementScreen extends StatefulWidget {
  const LabTestTypesManagementScreen({super.key});

  @override
  State<LabTestTypesManagementScreen> createState() => _LabTestTypesManagementScreenState();
}

class _LabTestTypesManagementScreenState extends State<LabTestTypesManagementScreen> {
  final DataService _dataService = DataService();
  List<LabTestTypeModel> _testTypes = [];
  bool _isLoading = true;
  LabTestCategory? _filterCategory;
  bool _showActiveOnly = true;

  @override
  void initState() {
    super.initState();
    _loadTestTypes();
  }

  Future<void> _loadTestTypes() async {
    setState(() => _isLoading = true);
    try {
      final testTypes = await _dataService.getLabTestTypes(
        category: _filterCategory,
        isActive: _showActiveOnly ? true : null,
      );
      setState(() {
        _testTypes = testTypes.cast<LabTestTypeModel>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل أنواع الفحوصات: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة أنواع الفحوصات'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              if (value == 'category') {
                _showCategoryFilter();
              } else if (value == 'clear') {
                setState(() {
                  _filterCategory = null;
                  _showActiveOnly = true;
                });
                _loadTestTypes();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'category', child: Text('فلترة حسب الفئة')),
              const PopupMenuItem(value: 'clear', child: Text('إزالة الفلاتر')),
            ],
          ),
          Switch(
            value: _showActiveOnly,
            onChanged: (value) {
              setState(() => _showActiveOnly = value);
              _loadTestTypes();
            },
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('نشطة فقط'),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _createTestType(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTestTypes,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTestTypes,
              child: _testTypes.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.science_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'لا توجد أنواع فحوصات',
                              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _testTypes.length,
                      itemBuilder: (context, index) {
                        final testType = _testTypes[index];
                        return _buildTestTypeCard(testType);
                      },
                    ),
            ),
    );
  }

  Widget _buildTestTypeCard(LabTestTypeModel testType) {
    final categoryText = {
      LabTestCategory.hematology: 'أمراض الدم',
      LabTestCategory.biochemistry: 'كيمياء حيوية',
      LabTestCategory.microbiology: 'ميكروبيولوجيا',
      LabTestCategory.immunology: 'مناعة',
      LabTestCategory.pathology: 'علم الأمراض',
      LabTestCategory.serology: 'مصلية',
      LabTestCategory.urinalysis: 'تحليل البول',
      LabTestCategory.other: 'أخرى',
    }[testType.category]!;

    final priorityText = {
      LabTestPriority.routine: 'روتيني',
      LabTestPriority.urgent: 'عاجل',
      LabTestPriority.stat: 'فوري',
    }[testType.defaultPriority]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: testType.isActive ? null : Colors.grey.shade100,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: testType.isActive ? Colors.blue : Colors.grey,
          child: Icon(
            Icons.science,
            color: Colors.white,
          ),
        ),
        title: Text(
          testType.arabicName ?? testType.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: testType.isActive ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الفئة: $categoryText'),
            Text('السعر: ${NumberFormat.currency(symbol: 'د.أ', decimalDigits: 2).format(testType.price)}'),
            if (testType.estimatedDurationMinutes != null)
              Text('المدة المتوقعة: ${testType.estimatedDurationMinutes} دقيقة'),
            Text('الأولوية الافتراضية: $priorityText'),
            if (!testType.isActive)
              const Text(
                'غير نشط',
                style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
              ),
          ],
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          // يمكن إضافة شاشة تفاصيل لاحقاً
        },
      ),
    );
  }

  void _showCategoryFilter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('فلترة حسب الفئة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<LabTestCategory?>(
              title: const Text('جميع الفئات'),
              value: null,
              groupValue: _filterCategory,
              onChanged: (value) {
                setState(() => _filterCategory = value);
                Navigator.pop(context);
                _loadTestTypes();
              },
            ),
            ...LabTestCategory.values.map((category) {
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

              return RadioListTile<LabTestCategory?>(
                title: Text(categoryText),
                value: category,
                groupValue: _filterCategory,
                onChanged: (value) {
                  setState(() => _filterCategory = value);
                  Navigator.pop(context);
                  _loadTestTypes();
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _createTestType() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateLabTestTypeScreen()),
    ).then((_) => _loadTestTypes());
  }
}

