import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../models/report_model.dart';
import '../../services/data_service.dart';

class QualityReportsScreen extends StatefulWidget {
  final DateTime fromDate;
  final DateTime toDate;

  const QualityReportsScreen({
    super.key,
    required this.fromDate,
    required this.toDate,
  });

  @override
  State<QualityReportsScreen> createState() => _QualityReportsScreenState();
}

class _QualityReportsScreenState extends State<QualityReportsScreen> {
  final DataService _dataService = DataService();
  List<QualityReport> _reports = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQualityData();
  }

  Future<void> _loadQualityData() async {
    setState(() => _isLoading = true);
    try {
      // يمكن جلب بيانات الجودة من مصادر مختلفة
      final reports = <QualityReport>[
        QualityReport(
          category: 'الوصفات الطبية',
          totalCases: 100,
          compliantCases: 95,
          nonCompliantCases: 5,
          metrics: {'averageTime': 15, 'errorRate': 0.05},
          reportDate: DateTime.now(),
        ),
        QualityReport(
          category: 'الفحوصات المختبرية',
          totalCases: 80,
          compliantCases: 78,
          nonCompliantCases: 2,
          metrics: {'averageTime': 30, 'errorRate': 0.025},
          reportDate: DateTime.now(),
        ),
        QualityReport(
          category: 'العمليات الجراحية',
          totalCases: 50,
          compliantCases: 48,
          nonCompliantCases: 2,
          metrics: {'averageTime': 120, 'errorRate': 0.04},
          reportDate: DateTime.now(),
        ),
      ];

      setState(() {
        _reports = reports;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل البيانات: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadQualityData,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildComplianceChart(),
                const SizedBox(height: 24),
                ..._reports.map((report) => _buildQualityCard(report)),
              ],
            ),
          );
  }

  Widget _buildComplianceChart() {
    if (_reports.isEmpty) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'معدل الامتثال',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: _reports.map((report) {
                    return PieChartSectionData(
                      value: report.complianceRate,
                      title: '${report.complianceRate.toStringAsFixed(1)}%',
                      color: _getCategoryColor(report.category),
                      radius: 50,
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'الوصفات الطبية':
        return Colors.blue;
      case 'الفحوصات المختبرية':
        return Colors.green;
      case 'العمليات الجراحية':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _buildQualityCard(QualityReport report) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getCategoryColor(report.category),
          child: const Icon(Icons.assessment, color: Colors.white),
        ),
        title: Text(report.category),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('إجمالي الحالات: ${report.totalCases}'),
            Text('متوافقة: ${report.compliantCases}'),
            Text('غير متوافقة: ${report.nonCompliantCases}'),
            Text('معدل الامتثال: ${report.complianceRate.toStringAsFixed(1)}%'),
            if (report.metrics.containsKey('averageTime'))
              Text('متوسط الوقت: ${report.metrics['averageTime']} دقيقة'),
            if (report.metrics.containsKey('errorRate'))
              Text('معدل الخطأ: ${(report.metrics['errorRate'] * 100).toStringAsFixed(2)}%'),
          ],
        ),
      ),
    );
  }
}

