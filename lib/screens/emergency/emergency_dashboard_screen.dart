import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/emergency_case_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider_local.dart';
import '../../services/data_service.dart';
import '../../utils/auth_helper.dart';
import 'emergency_case_details_screen.dart';
import 'create_emergency_case_screen.dart';
import 'emergency_events_screen.dart';
import 'emergency_statistics_screen.dart';

class EmergencyDashboardScreen extends StatefulWidget {
  const EmergencyDashboardScreen({super.key});

  @override
  State<EmergencyDashboardScreen> createState() => _EmergencyDashboardScreenState();
}

class _EmergencyDashboardScreenState extends State<EmergencyDashboardScreen>
    with SingleTickerProviderStateMixin {
  final DataService _dataService = DataService();
  List<EmergencyCaseModel> _cases = [];
  bool _isLoading = true;
  EmergencyStatus? _filterStatus;
  TriageLevel? _filterTriage;
  late TabController _tabController;

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCases();
    
    // تحديث تلقائي كل 30 ثانية للتحقق من الحالات الحرجة
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _loadCases();
        _checkCriticalCases();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _checkCriticalCases() {
    final criticalCases = _cases.where((c) => 
      c.triageLevel == TriageLevel.red && 
      c.status == EmergencyStatus.waiting
    ).toList();

    if (criticalCases.isNotEmpty && mounted) {
      // عرض تنبيه للحالات الحرجة
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'تنبيه: ${criticalCases.length} حالة حرجة تحتاج تدخل فوري!',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'عرض',
            textColor: Colors.white,
            onPressed: () {
              setState(() {
                _filterTriage = TriageLevel.red;
                _tabController.animateTo(0);
              });
              _loadCases();
            },
          ),
        ),
      );
    }
  }

  Future<void> _loadCases() async {
    setState(() => _isLoading = true);
    try {
      final cases = await _dataService.getEmergencyCases(
        status: _filterStatus,
        triage: _filterTriage,
      );
      setState(() {
        _cases = cases.cast<EmergencyCaseModel>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل الحالات: $e')),
        );
      }
    }
  }

  List<EmergencyCaseModel> get _filteredCases {
    return _cases;
  }

  Map<String, dynamic> get _summary {
    final total = _cases.length;
    final waiting = _cases.where((c) => c.status == EmergencyStatus.waiting).length;
    final inTreatment = _cases.where((c) => c.status == EmergencyStatus.in_treatment).length;
    final critical = _cases.where((c) => c.triageLevel == TriageLevel.red).length;
    final urgent = _cases.where((c) => c.triageLevel == TriageLevel.orange).length;

    return {
      'total': total,
      'waiting': waiting,
      'inTreatment': inTreatment,
      'critical': critical,
      'urgent': urgent,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('قسم الطوارئ'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'الحالات', icon: Icon(Icons.local_hospital)),
            Tab(text: 'الإحصائيات', icon: Icon(Icons.analytics)),
          ],
        ),
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              if (value == 'status') {
                _showStatusFilter();
              } else if (value == 'triage') {
                _showTriageFilter();
              } else if (value == 'clear') {
                setState(() {
                  _filterStatus = null;
                  _filterTriage = null;
                });
                _loadCases();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'status',
                child: Text('فلترة حسب الحالة'),
              ),
              const PopupMenuItem(
                value: 'triage',
                child: Text('فلترة حسب الترياج'),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Text('إزالة الفلاتر'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _createNewCase(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCases,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCasesTab(),
          _buildStatisticsTab(),
        ],
      ),
    );
  }

  Widget _buildCasesTab() {
    return Column(
      children: [
        _buildCriticalAlerts(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadCases,
                  child: _buildCasesList(),
                ),
        ),
      ],
    );
  }

  Widget _buildCriticalAlerts() {
    final criticalCases = _cases.where((c) => c.triageLevel == TriageLevel.red).toList();
    
    if (criticalCases.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.red.shade50,
      child: Row(
        children: [
          const Icon(Icons.warning, color: Colors.red, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'حالات حرجة: ${criticalCases.length}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const Text(
                  'يتطلب تدخل فوري',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCasesList() {
    if (_filteredCases.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.local_hospital_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'لا توجد حالات طوارئ',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    // ترتيب الحالات حسب الأولوية (الأحمر أولاً)
    final sortedCases = List<EmergencyCaseModel>.from(_filteredCases);
    sortedCases.sort((a, b) {
      final priorityOrder = {
        TriageLevel.red: 0,
        TriageLevel.orange: 1,
        TriageLevel.yellow: 2,
        TriageLevel.green: 3,
        TriageLevel.blue: 4,
      };
      return (priorityOrder[a.triageLevel] ?? 4)
          .compareTo(priorityOrder[b.triageLevel] ?? 4);
    });

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedCases.length,
      itemBuilder: (context, index) {
        final case_ = sortedCases[index];
        return _buildCaseCard(case_);
      },
    );
  }

  Widget _buildCaseCard(EmergencyCaseModel case_) {
    final triageColor = {
      TriageLevel.red: Colors.red,
      TriageLevel.orange: Colors.orange,
      TriageLevel.yellow: Colors.yellow,
      TriageLevel.green: Colors.green,
      TriageLevel.blue: Colors.blue,
    }[case_.triageLevel]!;

    final triageText = {
      TriageLevel.red: 'حرجة',
      TriageLevel.orange: 'عاجلة',
      TriageLevel.yellow: 'متوسطة',
      TriageLevel.green: 'بسيطة',
      TriageLevel.blue: 'غير عاجلة',
    }[case_.triageLevel]!;

    final statusText = {
      EmergencyStatus.waiting: 'قيد الانتظار',
      EmergencyStatus.in_treatment: 'قيد العلاج',
      EmergencyStatus.stabilized: 'مستقرة',
      EmergencyStatus.transferred: 'منقولة',
      EmergencyStatus.discharged: 'مفرج عنها',
    }[case_.status]!;

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm', 'ar');
    final waitTime = DateTime.now().difference(case_.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: case_.triageLevel == TriageLevel.red ? 4 : 2,
      color: case_.triageLevel == TriageLevel.red
          ? Colors.red.shade50
          : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: triageColor.withValues(alpha: 0.2),
          child: Icon(
            Icons.local_hospital,
            color: triageColor,
          ),
        ),
        title: Text(
          case_.patientName ?? 'مريض غير مسجل',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الترياج: $triageText'),
            Text('الحالة: $statusText'),
            Text('الوقت: ${dateFormat.format(case_.createdAt)}'),
            if (case_.status == EmergencyStatus.waiting)
              Text(
                'مدة الانتظار: ${waitTime.inMinutes} دقيقة',
                style: TextStyle(
                  color: waitTime.inMinutes > 30 ? Colors.red : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (case_.symptoms != null && case_.symptoms!.isNotEmpty)
              Text(
                'الأعراض: ${case_.symptoms}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Chip(
              label: Text(triageText, style: const TextStyle(fontSize: 12)),
              backgroundColor: triageColor.withValues(alpha: 0.2),
              labelStyle: TextStyle(color: triageColor, fontWeight: FontWeight.bold),
            ),
            if (case_.triageLevel == TriageLevel.red)
              const Icon(Icons.priority_high, color: Colors.red, size: 20),
          ],
        ),
        onTap: () => _viewCaseDetails(case_),
      ),
    );
  }

  Widget _buildStatisticsTab() {
    final summary = _summary;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'إحصائيات الطوارئ',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'إجمالي الحالات',
                  summary['total'].toString(),
                  Icons.local_hospital,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'قيد الانتظار',
                  summary['waiting'].toString(),
                  Icons.access_time,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'قيد العلاج',
                  summary['inTreatment'].toString(),
                  Icons.medical_services,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'حرجة',
                  summary['critical'].toString(),
                  Icons.warning,
                  Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStatCard(
            'عاجلة',
            summary['urgent'].toString(),
            Icons.priority_high,
            Colors.orange,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _viewDetailedStatistics(),
              icon: const Icon(Icons.assessment),
              label: const Text('عرض الإحصائيات التفصيلية'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
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
                fontSize: 20,
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

  void _createNewCase() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateEmergencyCaseScreen()),
    ).then((_) => _loadCases());
  }

  void _viewCaseDetails(EmergencyCaseModel case_) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmergencyCaseDetailsScreen(emergencyCase: case_),
      ),
    ).then((_) => _loadCases());
  }

  void _viewDetailedStatistics() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EmergencyStatisticsScreen()),
    );
  }

  void _showStatusFilter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('فلترة حسب الحالة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<EmergencyStatus?>(
              title: const Text('جميع الحالات'),
              value: null,
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() => _filterStatus = value);
                Navigator.pop(context);
                _loadCases();
              },
            ),
            RadioListTile<EmergencyStatus?>(
              title: const Text('قيد الانتظار'),
              value: EmergencyStatus.waiting,
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() => _filterStatus = value);
                Navigator.pop(context);
                _loadCases();
              },
            ),
            RadioListTile<EmergencyStatus?>(
              title: const Text('قيد العلاج'),
              value: EmergencyStatus.in_treatment,
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() => _filterStatus = value);
                Navigator.pop(context);
                _loadCases();
              },
            ),
            RadioListTile<EmergencyStatus?>(
              title: const Text('مستقرة'),
              value: EmergencyStatus.stabilized,
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() => _filterStatus = value);
                Navigator.pop(context);
                _loadCases();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showTriageFilter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('فلترة حسب الترياج'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<TriageLevel?>(
              title: const Text('جميع المستويات'),
              value: null,
              groupValue: _filterTriage,
              onChanged: (value) {
                setState(() => _filterTriage = value);
                Navigator.pop(context);
                _loadCases();
              },
            ),
            RadioListTile<TriageLevel?>(
              title: const Text('حرجة (أحمر)'),
              value: TriageLevel.red,
              groupValue: _filterTriage,
              onChanged: (value) {
                setState(() => _filterTriage = value);
                Navigator.pop(context);
                _loadCases();
              },
            ),
            RadioListTile<TriageLevel?>(
              title: const Text('عاجلة (برتقالي)'),
              value: TriageLevel.orange,
              groupValue: _filterTriage,
              onChanged: (value) {
                setState(() => _filterTriage = value);
                Navigator.pop(context);
                _loadCases();
              },
            ),
            RadioListTile<TriageLevel?>(
              title: const Text('متوسطة (أصفر)'),
              value: TriageLevel.yellow,
              groupValue: _filterTriage,
              onChanged: (value) {
                setState(() => _filterTriage = value);
                Navigator.pop(context);
                _loadCases();
              },
            ),
            RadioListTile<TriageLevel?>(
              title: const Text('بسيطة (أخضر)'),
              value: TriageLevel.green,
              groupValue: _filterTriage,
              onChanged: (value) {
                setState(() => _filterTriage = value);
                Navigator.pop(context);
                _loadCases();
              },
            ),
          ],
        ),
      ),
    );
  }
}

