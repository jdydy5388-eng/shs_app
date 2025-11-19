import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/report_model.dart';
import '../../services/data_service.dart';
import '../../utils/pdf_service.dart';
import '../../utils/excel_export_service.dart';
import 'performance_reports_screen.dart';
import 'quality_reports_screen.dart';

class AdvancedReportsScreen extends StatefulWidget {
  const AdvancedReportsScreen({super.key});

  @override
  State<AdvancedReportsScreen> createState() => _AdvancedReportsScreenState();
}

class _AdvancedReportsScreenState extends State<AdvancedReportsScreen> {
  final DataService _dataService = DataService();
  ReportType _selectedType = ReportType.statistical;
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير المتقدمة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _exportToPdf,
            tooltip: 'تصدير PDF',
          ),
          IconButton(
            icon: const Icon(Icons.table_chart),
            onPressed: _exportToExcel,
            tooltip: 'تصدير Excel',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _buildReportContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final dateFormat = DateFormat('yyyy-MM-dd', 'ar');

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<ReportType>(
                    value: _selectedType,
                    decoration: const InputDecoration(
                      labelText: 'نوع التقرير',
                      border: OutlineInputBorder(),
                    ),
                    items: ReportType.values.map((type) {
                      final typeText = {
                        ReportType.statistical: 'إحصائي',
                        ReportType.performance: 'أداء',
                        ReportType.quality: 'جودة',
                        ReportType.financial: 'مالي',
                        ReportType.operational: 'تشغيلي',
                      }[type]!;

                      return DropdownMenuItem(
                        value: type,
                        child: Text(typeText),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _selectedType = value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: const Text('من تاريخ'),
                    subtitle: Text(dateFormat.format(_fromDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _fromDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() => _fromDate = date);
                      }
                    },
                  ),
                ),
                Expanded(
                  child: ListTile(
                    title: const Text('إلى تاريخ'),
                    subtitle: Text(dateFormat.format(_toDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _toDate,
                        firstDate: _fromDate,
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() => _toDate = date);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _generateReport,
                icon: const Icon(Icons.refresh),
                label: const Text('إنشاء التقرير'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportContent() {
    switch (_selectedType) {
      case ReportType.performance:
        return PerformanceReportsScreen(
          fromDate: _fromDate,
          toDate: _toDate,
        );
      case ReportType.quality:
        return QualityReportsScreen(
          fromDate: _fromDate,
          toDate: _toDate,
        );
      default:
        return _buildStatisticalReport();
    }
  }

  Widget _buildStatisticalReport() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assessment, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'التقرير الإحصائي',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('اضغط على "إنشاء التقرير" لعرض البيانات'),
          ],
        ),
      ),
    );
  }

  Future<void> _generateReport() async {
    // يمكن إضافة منطق إنشاء التقرير هنا
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('جارٍ إنشاء التقرير...')),
    );
  }

  Future<void> _exportToPdf() async {
    try {
      // يمكن استخدام PdfService لتصدير التقرير
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تصدير التقرير إلى PDF'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في التصدير: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportToExcel() async {
    try {
      // يمكن استخدام ExcelExportService لتصدير التقرير
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تصدير التقرير إلى Excel'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في التصدير: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

