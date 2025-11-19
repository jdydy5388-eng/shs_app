import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../models/report_model.dart';
import '../../models/invoice_model.dart';
import '../../models/room_bed_model.dart';
import '../../models/lab_request_model.dart';
import '../../services/data_service.dart';
import 'advanced_reports_screen.dart';

class AdvancedDashboardScreen extends StatefulWidget {
  const AdvancedDashboardScreen({super.key});

  @override
  State<AdvancedDashboardScreen> createState() => _AdvancedDashboardScreenState();
}

class _AdvancedDashboardScreenState extends State<AdvancedDashboardScreen> {
  final DataService _dataService = DataService();
  DashboardStats? _stats;
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      // جلب البيانات من مختلف المصادر
      final patients = await _dataService.getPatients();
      final doctors = await _dataService.getUsers(role: 'doctor');
      // الحصول على جميع المواعيد
      final doctors = await _dataService.getUsers(role: 'doctor');
      final List<DoctorAppointment> allAppointments = [];
      for (var doctor in doctors) {
        final doctorAppointments = await _dataService.getDoctorAppointments(doctor.id);
        allAppointments.addAll(doctorAppointments.cast<DoctorAppointment>());
      }
      final appointments = allAppointments;
      final prescriptions = await _dataService.getPrescriptions();
      final invoices = await _dataService.getInvoices();
      final beds = await _dataService.getBeds();
      final labRequests = await _dataService.getLabRequests();
      final emergencyCases = await _dataService.getEmergencyCases();
      
      // جلب العمليات النشطة
      List surgeries = [];
      try {
        surgeries = await _dataService.getSurgeries(status: 'in_progress');
      } catch (e) {
        // تجاهل الخطأ إذا لم تكن الدالة متاحة
      }

      // حساب الإيرادات
      double totalRevenue = 0.0;
      for (final invoice in invoices) {
        if (invoice is InvoiceModel) {
          totalRevenue += invoice.total;
        }
      }

      // حساب الأسرة المشغولة
      final bedsList = beds.cast<BedModel>();
      final occupiedBeds = bedsList.where((b) => b.status == BedStatus.occupied).length;
      final totalBeds = bedsList.length;

      // حساب طلبات المختبر
      final labRequestsList = labRequests.cast<LabRequestModel>();
      final pendingLab = labRequestsList.where((r) => r.status == LabRequestStatus.pending).length;
      final completedLab = labRequestsList.where((r) => r.status == LabRequestStatus.completed).length;

      setState(() {
        _stats = DashboardStats(
          totalPatients: patients.length,
          totalDoctors: doctors.length,
          totalAppointments: appointments.length,
          totalPrescriptions: prescriptions.length,
          totalRevenue: totalRevenue,
          occupiedBeds: occupiedBeds,
          totalBeds: totalBeds,
          pendingLabRequests: pendingLab,
          completedLabRequests: completedLab,
          emergencyCases: emergencyCases.length,
          activeSurgeries: surgeries.length,
        );
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة المعلومات الشاملة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.assessment),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdvancedReportsScreen()),
            ),
            tooltip: 'التقارير المتقدمة',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatsGrid(),
                    const SizedBox(height: 24),
                    _buildRevenueChart(),
                    const SizedBox(height: 24),
                    _buildOccupancyChart(),
                    const SizedBox(height: 24),
                    _buildLabRequestsChart(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatsGrid() {
    if (_stats == null) return const SizedBox();

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'إجمالي المرضى',
          _stats!.totalPatients.toString(),
          Icons.people,
          Colors.blue,
        ),
        _buildStatCard(
          'إجمالي الأطباء',
          _stats!.totalDoctors.toString(),
          Icons.local_hospital,
          Colors.green,
        ),
        _buildStatCard(
          'المواعيد',
          _stats!.totalAppointments.toString(),
          Icons.calendar_today,
          Colors.orange,
        ),
        _buildStatCard(
          'الوصفات الطبية',
          _stats!.totalPrescriptions.toString(),
          Icons.description,
          Colors.purple,
        ),
        _buildStatCard(
          'الإيرادات',
          NumberFormat.currency(symbol: 'د.أ', decimalDigits: 0).format(_stats!.totalRevenue),
          Icons.attach_money,
          Colors.teal,
        ),
        _buildStatCard(
          'معدل إشغال الأسرة',
          '${_stats!.bedOccupancyRate.toStringAsFixed(1)}%',
          Icons.bed,
          Colors.indigo,
        ),
        _buildStatCard(
          'حالات الطوارئ',
          _stats!.emergencyCases.toString(),
          Icons.emergency,
          Colors.red,
        ),
        _buildStatCard(
          'العمليات النشطة',
          _stats!.activeSurgeries.toString(),
          Icons.medical_services,
          Colors.pink,
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
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
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueChart() {
    if (_stats == null) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'الإيرادات',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _stats!.totalRevenue * 1.2,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            NumberFormat.compact().format(value),
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
                  barGroups: [
                    BarChartGroupData(
                      x: 0,
                      barRods: [
                        BarChartRodData(
                          toY: _stats!.totalRevenue,
                          color: Colors.teal,
                          width: 20,
                        ),
                      ],
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

  Widget _buildOccupancyChart() {
    if (_stats == null) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'معدل إشغال الأسرة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: [
                    PieChartSectionData(
                      value: _stats!.occupiedBeds.toDouble(),
                      title: '${_stats!.occupiedBeds} مشغولة',
                      color: Colors.blue,
                      radius: 50,
                    ),
                    PieChartSectionData(
                      value: (_stats!.totalBeds - _stats!.occupiedBeds).toDouble(),
                      title: '${_stats!.totalBeds - _stats!.occupiedBeds} متاحة',
                      color: Colors.grey,
                      radius: 50,
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

  Widget _buildLabRequestsChart() {
    if (_stats == null) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'طلبات المختبر',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: (_stats!.pendingLabRequests + _stats!.completedLabRequests) * 1.2,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() == 0) return const Text('قيد الانتظار');
                          if (value.toInt() == 1) return const Text('مكتملة');
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
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
                  barGroups: [
                    BarChartGroupData(
                      x: 0,
                      barRods: [
                        BarChartRodData(
                          toY: _stats!.pendingLabRequests.toDouble(),
                          color: Colors.orange,
                          width: 30,
                        ),
                      ],
                    ),
                    BarChartGroupData(
                      x: 1,
                      barRods: [
                        BarChartRodData(
                          toY: _stats!.completedLabRequests.toDouble(),
                          color: Colors.green,
                          width: 30,
                        ),
                      ],
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
}

