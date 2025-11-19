import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/emergency_case_model.dart';
import '../../services/data_service.dart';

class EmergencyStatisticsScreen extends StatefulWidget {
  const EmergencyStatisticsScreen({super.key});

  @override
  State<EmergencyStatisticsScreen> createState() => _EmergencyStatisticsScreenState();
}

class _EmergencyStatisticsScreenState extends State<EmergencyStatisticsScreen> {
  final DataService _dataService = DataService();
  List<EmergencyCaseModel> _cases = [];
  bool _isLoading = true;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final cases = await _dataService.getEmergencyCases();
      setState(() {
        _cases = cases.cast<EmergencyCaseModel>();
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

  List<EmergencyCaseModel> get _filteredCases {
    return _cases.where((case_) {
      return case_.createdAt.isAfter(_startDate.subtract(const Duration(days: 1))) &&
          case_.createdAt.isBefore(_endDate.add(const Duration(days: 1)));
    }).toList();
  }

  Map<String, dynamic> get _statistics {
    final filtered = _filteredCases;
    
    // إحصائيات حسب الترياج
    final byTriage = <TriageLevel, int>{};
    for (final level in TriageLevel.values) {
      byTriage[level] = filtered.where((c) => c.triageLevel == level).length;
    }

    // إحصائيات حسب الحالة
    final byStatus = <EmergencyStatus, int>{};
    for (final status in EmergencyStatus.values) {
      byStatus[status] = filtered.where((c) => c.status == status).length;
    }

    // متوسط أوقات الانتظار
    final waitingCases = filtered.where((c) => c.status == EmergencyStatus.waiting).toList();
    final avgWaitTime = waitingCases.isEmpty
        ? 0.0
        : waitingCases
            .map((c) => DateTime.now().difference(c.createdAt).inMinutes)
            .fold(0, (a, b) => a + b) /
            waitingCases.length;

    // حالات حرجة
    final criticalCases = filtered.where((c) => c.triageLevel == TriageLevel.red).length;

    return {
      'total': filtered.length,
      'byTriage': byTriage,
      'byStatus': byStatus,
      'avgWaitTime': avgWaitTime,
      'criticalCases': criticalCases,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إحصائيات الطوارئ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDateRangeSelector(),
                  const SizedBox(height: 24),
                  _buildSummaryCards(),
                  const SizedBox(height: 24),
                  _buildTriageChart(),
                  const SizedBox(height: 24),
                  _buildStatusChart(),
                  const SizedBox(height: 24),
                  _buildWaitTimeCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildDateRangeSelector() {
    final dateFormat = DateFormat('yyyy-MM-dd', 'ar');
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'اختر الفترة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: const Text('من تاريخ'),
                    subtitle: Text(dateFormat.format(_startDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() => _startDate = date);
                      }
                    },
                  ),
                ),
                Expanded(
                  child: ListTile(
                    title: const Text('إلى تاريخ'),
                    subtitle: Text(dateFormat.format(_endDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _endDate,
                        firstDate: _startDate,
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() => _endDate = date);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final stats = _statistics;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'إجمالي الحالات',
                stats['total'].toString(),
                Icons.local_hospital,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'حالات حرجة',
                stats['criticalCases'].toString(),
                Icons.warning,
                Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          'متوسط وقت الانتظار',
          '${(stats['avgWaitTime'] as double).toStringAsFixed(1)} دقيقة',
          Icons.access_time,
          Colors.orange,
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTriageChart() {
    final stats = _statistics;
    final byTriage = stats['byTriage'] as Map<TriageLevel, int>;
    final total = byTriage.values.fold(0, (a, b) => a + b);

    final triageLabels = {
      TriageLevel.red: 'حرجة',
      TriageLevel.orange: 'عاجلة',
      TriageLevel.yellow: 'متوسطة',
      TriageLevel.green: 'بسيطة',
      TriageLevel.blue: 'غير عاجلة',
    };

    final triageColors = {
      TriageLevel.red: Colors.red,
      TriageLevel.orange: Colors.orange,
      TriageLevel.yellow: Colors.yellow,
      TriageLevel.green: Colors.green,
      TriageLevel.blue: Colors.blue,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'توزيع الحالات حسب الترياج',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (total > 0)
              ...byTriage.entries.map((entry) {
                final percentage = total > 0 ? (entry.value / total * 100) : 0.0;
                return _buildChartBar(
                  triageLabels[entry.key]!,
                  entry.value,
                  total,
                  triageColors[entry.key]!,
                );
              })
            else
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('لا توجد بيانات'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChart() {
    final stats = _statistics;
    final byStatus = stats['byStatus'] as Map<EmergencyStatus, int>;
    final total = byStatus.values.fold(0, (a, b) => a + b);

    final statusLabels = {
      EmergencyStatus.waiting: 'قيد الانتظار',
      EmergencyStatus.in_treatment: 'قيد العلاج',
      EmergencyStatus.stabilized: 'مستقرة',
      EmergencyStatus.transferred: 'منقولة',
      EmergencyStatus.discharged: 'مفرج عنها',
    };

    final statusColors = {
      EmergencyStatus.waiting: Colors.orange,
      EmergencyStatus.in_treatment: Colors.blue,
      EmergencyStatus.stabilized: Colors.green,
      EmergencyStatus.transferred: Colors.purple,
      EmergencyStatus.discharged: Colors.grey,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'توزيع الحالات حسب الحالة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (total > 0)
              ...byStatus.entries.map((entry) {
                final percentage = total > 0 ? (entry.value / total * 100) : 0.0;
                return _buildChartBar(
                  statusLabels[entry.key]!,
                  entry.value,
                  total,
                  statusColors[entry.key]!,
                );
              })
            else
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('لا توجد بيانات'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartBar(String label, int value, int total, Color color) {
    final percentage = total > 0 ? (value / total * 100) : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label),
              Text(
                '$value (${percentage.toStringAsFixed(1)}%)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total > 0 ? value / total : 0,
              minHeight: 20,
              backgroundColor: color.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitTimeCard() {
    final stats = _statistics;
    final avgWaitTime = stats['avgWaitTime'] as double;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'أوقات الانتظار',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildStatRow('متوسط وقت الانتظار', '${avgWaitTime.toStringAsFixed(1)} دقيقة'),
            const SizedBox(height: 8),
            if (avgWaitTime > 30)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'متوسط وقت الانتظار مرتفع - يوصى بزيادة الموارد',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

