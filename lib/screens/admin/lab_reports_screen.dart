import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/lab_request_model.dart';
import '../../models/lab_test_type_model.dart';
import '../../services/data_service.dart';

class LabReportsScreen extends StatefulWidget {
  const LabReportsScreen({super.key});

  @override
  State<LabReportsScreen> createState() => _LabReportsScreenState();
}

class _LabReportsScreenState extends State<LabReportsScreen> {
  final DataService _dataService = DataService();
  List<LabRequestModel> _requests = [];
  bool _isLoading = true;
  DateTime? _fromDate;
  DateTime? _toDate;
  LabTestCategory? _filterCategory;

  @override
  void initState() {
    super.initState();
    _fromDate = DateTime.now().subtract(const Duration(days: 30));
    _toDate = DateTime.now();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    try {
      final requests = await _dataService.getLabRequests();
      // فلترة حسب التاريخ
      final filtered = requests.cast<LabRequestModel>().where((r) {
        if (_fromDate != null && r.requestedAt.isBefore(_fromDate!)) return false;
        if (_toDate != null && r.requestedAt.isAfter(_toDate!)) return false;
        return true;
      }).toList();
      
      setState(() {
        _requests = filtered;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل التقارير: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd', 'ar');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير المختبرية'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReports,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_fromDate != null || _toDate != null)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.blue.shade50,
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'من: ${_fromDate != null ? dateFormat.format(_fromDate!) : 'بداية'} - '
                    'إلى: ${_toDate != null ? dateFormat.format(_toDate!) : 'نهاية'}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          _buildStatistics(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadReports,
                    child: _requests.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.assessment_outlined,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'لا توجد تقارير في الفترة المحددة',
                                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _requests.length,
                            itemBuilder: (context, index) {
                              final request = _requests[index];
                              return _buildReportCard(request);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatistics() {
    final total = _requests.length;
    final completed = _requests.where((r) => r.status == LabRequestStatus.completed).length;
    final pending = _requests.where((r) => r.status == LabRequestStatus.pending).length;
    final inProgress = _requests.where((r) => r.status == LabRequestStatus.inProgress).length;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'إحصائيات',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard('إجمالي', total.toString(), Colors.blue),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard('مكتملة', completed.toString(), Colors.green),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard('قيد الانتظار', pending.toString(), Colors.orange),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard('قيد التنفيذ', inProgress.toString(), Colors.blue),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(LabRequestModel request) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm', 'ar');
    
    final statusColor = {
      LabRequestStatus.pending: Colors.orange,
      LabRequestStatus.inProgress: Colors.blue,
      LabRequestStatus.completed: Colors.green,
      LabRequestStatus.cancelled: Colors.red,
    }[request.status]!;

    final statusText = {
      LabRequestStatus.pending: 'قيد الانتظار',
      LabRequestStatus.inProgress: 'قيد التنفيذ',
      LabRequestStatus.completed: 'مكتملة',
      LabRequestStatus.cancelled: 'ملغاة',
    }[request.status]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.2),
          child: Icon(Icons.science, color: statusColor),
        ),
        title: Text(
          request.testType,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('المريض: ${request.patientName}'),
            if (request.diagnosisName != null)
              Text('الحالة: ${request.diagnosisName}', style: const TextStyle(color: Colors.blue)),
            Text('التاريخ: ${dateFormat.format(request.requestedAt)}'),
            if (request.completedAt != null)
              Text('اكتمل: ${dateFormat.format(request.completedAt!)}', style: const TextStyle(color: Colors.green)),
          ],
        ),
        trailing: Chip(
          label: Text(statusText, style: const TextStyle(fontSize: 12)),
          backgroundColor: statusColor.withValues(alpha: 0.2),
          labelStyle: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
        ),
        onTap: () {
          // يمكن إضافة شاشة تفاصيل التقرير
        },
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final from = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now().subtract(const Duration(days: 30)),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (from == null) return;

    final to = await showDatePicker(
      context: context,
      initialDate: _toDate ?? DateTime.now(),
      firstDate: from,
      lastDate: DateTime.now(),
    );

    if (to == null) return;

    setState(() {
      _fromDate = from;
      _toDate = to;
    });
    _loadReports();
  }
}

