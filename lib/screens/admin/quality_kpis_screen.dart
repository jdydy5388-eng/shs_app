import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/quality_models.dart';
import '../../services/data_service.dart';
import '../../utils/auth_helper.dart';
import 'create_kpi_screen.dart';
import 'kpi_details_screen.dart';

class QualityKPIsScreen extends StatefulWidget {
  const QualityKPIsScreen({super.key});

  @override
  State<QualityKPIsScreen> createState() => _QualityKPIsScreenState();
}

class _QualityKPIsScreenState extends State<QualityKPIsScreen> {
  final DataService _dataService = DataService();
  List<KPIModel> _kpis = [];
  bool _isLoading = true;
  KPICategory? _filterCategory;

  @override
  void initState() {
    super.initState();
    _loadKPIs();
  }

  Future<void> _loadKPIs() async {
    setState(() => _isLoading = true);
    try {
      final kpis = await _dataService.getKPIs(category: _filterCategory);
      setState(() {
        _kpis = kpis.cast<KPIModel>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل مؤشرات الجودة: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadKPIs,
                    child: _kpis.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.analytics_outlined,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'لا توجد مؤشرات جودة',
                                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _kpis.length,
                            itemBuilder: (context, index) {
                              return _buildKPICard(_kpis[index]);
                            },
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateKPIScreen()),
        ).then((_) => _loadKPIs()),
        icon: const Icon(Icons.add),
        label: const Text('إضافة مؤشر'),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<KPICategory?>(
              value: _filterCategory,
              decoration: const InputDecoration(
                labelText: 'فلترة حسب الفئة',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('جميع الفئات')),
                ...KPICategory.values.map((cat) {
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
                }),
              ],
              onChanged: (value) {
                setState(() => _filterCategory = value);
                _loadKPIs();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKPICard(KPIModel kpi) {
    final dateFormat = DateFormat('yyyy-MM-dd', 'ar');
    
    final categoryText = {
      KPICategory.patientSafety: 'سلامة المرضى',
      KPICategory.clinicalOutcomes: 'النتائج السريرية',
      KPICategory.patientSatisfaction: 'رضا المرضى',
      KPICategory.operationalEfficiency: 'الكفاءة التشغيلية',
      KPICategory.financial: 'مالي',
      KPICategory.infectionControl: 'مكافحة العدوى',
      KPICategory.medicationSafety: 'سلامة الأدوية',
      KPICategory.other: 'أخرى',
    }[kpi.category]!;

    final typeText = {
      KPIType.percentage: 'نسبة مئوية',
      KPIType.count: 'عدد',
      KPIType.rate: 'معدل',
      KPIType.average: 'متوسط',
      KPIType.time: 'وقت',
    }[kpi.type]!;

    final progress = kpi.targetValue != null && kpi.currentValue != null
        ? (kpi.currentValue! / kpi.targetValue!).clamp(0.0, 1.0)
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => KPIDetailsScreen(kpiId: kpi.id),
          ),
        ).then((_) => _loadKPIs()),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          kpi.arabicName ?? kpi.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          categoryText,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      typeText,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (kpi.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  kpi.description,
                  style: TextStyle(color: Colors.grey[700]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (kpi.currentValue != null || kpi.targetValue != null) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (kpi.currentValue != null)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'القيمة الحالية',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                            Text(
                              '${kpi.currentValue!.toStringAsFixed(2)}${kpi.unit ?? ''}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (kpi.targetValue != null)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'المستهدف',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                            Text(
                              '${kpi.targetValue!.toStringAsFixed(2)}${kpi.unit ?? ''}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (progress != null) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress >= 1.0 ? Colors.green : Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(progress * 100).toStringAsFixed(1)}% من الهدف',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ],
              if (kpi.lastUpdated != null) ...[
                const SizedBox(height: 8),
                Text(
                  'آخر تحديث: ${dateFormat.format(kpi.lastUpdated!)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

