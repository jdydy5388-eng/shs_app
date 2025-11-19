import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../models/report_model.dart';
import '../../models/user_model.dart';
import '../../services/data_service.dart';

class PerformanceReportsScreen extends StatefulWidget {
  final DateTime fromDate;
  final DateTime toDate;

  const PerformanceReportsScreen({
    super.key,
    required this.fromDate,
    required this.toDate,
  });

  @override
  State<PerformanceReportsScreen> createState() => _PerformanceReportsScreenState();
}

class _PerformanceReportsScreenState extends State<PerformanceReportsScreen> {
  final DataService _dataService = DataService();
  List<PerformanceReport> _reports = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPerformanceData();
  }

  Future<void> _loadPerformanceData() async {
    setState(() => _isLoading = true);
    try {
      final doctors = await _dataService.getUsers(role: 'doctor');
      final reports = <PerformanceReport>[];

      for (final doctor in doctors) {
        if (doctor is UserModel) {
          final appointments = await _dataService.getDoctorAppointments(doctor.id);
          final prescriptions = await _dataService.getPrescriptions(doctorId: doctor.id);
          final labRequests = await _dataService.getLabRequests(doctorId: doctor.id);

          final completedAppointments = appointments.where((a) {
            // يمكن إضافة منطق للتحقق من اكتمال الموعد
            return true;
          }).length;

          reports.add(PerformanceReport(
            userId: doctor.id,
            userName: doctor.name,
            userRole: doctor.role.toString().split('.').last,
            totalAppointments: appointments.length,
            completedAppointments: completedAppointments,
            totalPrescriptions: prescriptions.length,
            totalLabRequests: labRequests.length,
            averageRating: 4.5, // يمكن جلبها من قاعدة البيانات
            reportDate: DateTime.now(),
          ));
        }
      }

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
            onRefresh: _loadPerformanceData,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildPerformanceChart(),
                const SizedBox(height: 24),
                ..._reports.map((report) => _buildPerformanceCard(report)),
              ],
            ),
          );
  }

  Widget _buildPerformanceChart() {
    if (_reports.isEmpty) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'معدل إكمال المواعيد',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 100,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() < _reports.length) {
                            return Text(
                              _reports[value.toInt()].userName.substring(0, 3),
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}%',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(show: true),
                  borderData: FlBorderData(show: false),
                  barGroups: _reports.asMap().entries.map((entry) {
                    final index = entry.key;
                    final report = entry.value;
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: report.appointmentCompletionRate,
                          color: Colors.blue,
                          width: 20,
                        ),
                      ],
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

  Widget _buildPerformanceCard(PerformanceReport report) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue,
          child: Text(report.userName[0].toUpperCase()),
        ),
        title: Text(report.userName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('المواعيد: ${report.totalAppointments} (${report.completedAppointments} مكتملة)'),
            Text('الوصفات: ${report.totalPrescriptions}'),
            Text('طلبات المختبر: ${report.totalLabRequests}'),
            Text('معدل الإكمال: ${report.appointmentCompletionRate.toStringAsFixed(1)}%'),
            Text('التقييم: ${report.averageRating.toStringAsFixed(1)}/5.0'),
          ],
        ),
      ),
    );
  }
}

