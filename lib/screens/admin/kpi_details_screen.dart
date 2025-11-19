import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/quality_models.dart';
import '../../services/data_service.dart';
import '../../utils/auth_helper.dart';

class KPIDetailsScreen extends StatefulWidget {
  final String kpiId;

  const KPIDetailsScreen({super.key, required this.kpiId});

  @override
  State<KPIDetailsScreen> createState() => _KPIDetailsScreenState();
}

class _KPIDetailsScreenState extends State<KPIDetailsScreen> {
  final DataService _dataService = DataService();
  KPIModel? _kpi;
  bool _isLoading = true;
  final _currentValueController = TextEditingController();
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadKPI();
  }

  @override
  void dispose() {
    _currentValueController.dispose();
    super.dispose();
  }

  Future<void> _loadKPI() async {
    setState(() => _isLoading = true);
    try {
      final kpi = await _dataService.getKPI(widget.kpiId);
      if (kpi != null && kpi is KPIModel) {
        setState(() {
          _kpi = kpi;
          _currentValueController.text = kpi.currentValue?.toString() ?? '';
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('المؤشر غير موجود')),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل المؤشر: $e')),
        );
      }
    }
  }

  Future<void> _updateCurrentValue() async {
    if (_kpi == null) return;

    final value = double.tryParse(_currentValueController.text.trim());
    if (value == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال قيمة صحيحة')),
      );
      return;
    }

    setState(() => _isUpdating = true);
    try {
      final currentUser = AuthHelper.getCurrentUser(context);
      await _dataService.updateKPI(
        widget.kpiId,
        currentValue: value,
        lastUpdated: DateTime.now(),
        updatedBy: currentUser?.id,
      );
      await _loadKPI();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث القيمة بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحديث القيمة: $e')),
        );
      }
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_kpi == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل المؤشر')),
        body: const Center(child: Text('المؤشر غير موجود')),
      );
    }

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm', 'ar');
    final progress = _kpi!.targetValue != null && _kpi!.currentValue != null
        ? (_kpi!.currentValue! / _kpi!.targetValue!).clamp(0.0, 1.0)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل مؤشر الجودة'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _kpi!.arabicName ?? _kpi!.name,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _kpi!.description,
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'معلومات المؤشر',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow('الفئة', _getCategoryText(_kpi!.category)),
                    _buildInfoRow('النوع', _getTypeText(_kpi!.type)),
                    if (_kpi!.unit != null) _buildInfoRow('الوحدة', _kpi!.unit!),
                    if (_kpi!.lastUpdated != null)
                      _buildInfoRow('آخر تحديث', dateFormat.format(_kpi!.lastUpdated!)),
                    if (_kpi!.updatedBy != null)
                      _buildInfoRow('حدث بواسطة', _kpi!.updatedBy!),
                  ],
                ),
              ),
            ),
            if (_kpi!.currentValue != null || _kpi!.targetValue != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'القيم',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      if (_kpi!.currentValue != null)
                        _buildValueCard(
                          'القيمة الحالية',
                          '${_kpi!.currentValue!.toStringAsFixed(2)}${_kpi!.unit ?? ''}',
                          Colors.blue,
                        ),
                      if (_kpi!.targetValue != null)
                        _buildValueCard(
                          'القيمة المستهدفة',
                          '${_kpi!.targetValue!.toStringAsFixed(2)}${_kpi!.unit ?? ''}',
                          Colors.green,
                        ),
                      if (progress != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          'التقدم: ${(progress * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progress >= 1.0 ? Colors.green : Colors.blue,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'تحديث القيمة الحالية',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _currentValueController,
                      decoration: InputDecoration(
                        labelText: 'القيمة الحالية',
                        hintText: 'أدخل القيمة الجديدة',
                        suffixText: _kpi!.unit,
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isUpdating ? null : _updateCurrentValue,
                      child: _isUpdating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('تحديث القيمة'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildValueCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _getCategoryText(KPICategory category) {
    return {
      KPICategory.patientSafety: 'سلامة المرضى',
      KPICategory.clinicalOutcomes: 'النتائج السريرية',
      KPICategory.patientSatisfaction: 'رضا المرضى',
      KPICategory.operationalEfficiency: 'الكفاءة التشغيلية',
      KPICategory.financial: 'مالي',
      KPICategory.infectionControl: 'مكافحة العدوى',
      KPICategory.medicationSafety: 'سلامة الأدوية',
      KPICategory.other: 'أخرى',
    }[category]!;
  }

  String _getTypeText(KPIType type) {
    return {
      KPIType.percentage: 'نسبة مئوية',
      KPIType.count: 'عدد',
      KPIType.rate: 'معدل',
      KPIType.average: 'متوسط',
      KPIType.time: 'وقت',
    }[type]!;
  }
}

