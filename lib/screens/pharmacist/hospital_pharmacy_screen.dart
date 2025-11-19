import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../models/hospital_pharmacy_model.dart';
import '../../services/data_service.dart';
import '../../utils/auth_helper.dart';
import 'dispense_medication_screen.dart';
import 'medication_schedules_screen.dart';
import 'medication_dispense_history_screen.dart';

class HospitalPharmacyScreen extends StatefulWidget {
  const HospitalPharmacyScreen({super.key});

  @override
  State<HospitalPharmacyScreen> createState() => _HospitalPharmacyScreenState();
}

class _HospitalPharmacyScreenState extends State<HospitalPharmacyScreen>
    with SingleTickerProviderStateMixin {
  final DataService _dataService = DataService();
  List<HospitalPharmacyDispenseModel> _dispenses = [];
  bool _isLoading = true;
  MedicationDispenseStatus? _filterStatus;
  Timer? _refreshTimer;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDispenses();
    // تحديث تلقائي كل 30 ثانية
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadDispenses());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDispenses() async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      final dispenses = await _dataService.getHospitalPharmacyDispenses(
        status: _filterStatus,
        from: todayStart,
        to: todayEnd,
      );
      
      setState(() {
        _dispenses = dispenses.cast<HospitalPharmacyDispenseModel>();
        _isLoading = false;
      });

      // التحقق من الأدوية المستحقة
      _checkDueMedications();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل البيانات: $e')),
        );
      }
    }
  }

  void _checkDueMedications() {
    final dueSoon = _dispenses.where((d) => d.isDueSoon && d.status == MedicationDispenseStatus.scheduled).toList();
    final overdue = _dispenses.where((d) => d.isOverdue && d.status == MedicationDispenseStatus.scheduled).toList();

    if (overdue.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'تنبيه: ${overdue.length} دواء متأخر عن موعده!',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } else if (dueSoon.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.access_time, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${dueSoon.length} دواء مستحق قريباً',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  List<HospitalPharmacyDispenseModel> get _scheduledDispenses {
    return _dispenses.where((d) => d.status == MedicationDispenseStatus.scheduled).toList()
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
  }

  List<HospitalPharmacyDispenseModel> get _dispensedToday {
    return _dispenses.where((d) => 
      d.status == MedicationDispenseStatus.dispensed &&
      d.dispensedAt != null &&
      d.dispensedAt!.day == DateTime.now().day
    ).toList()
      ..sort((a, b) => (b.dispensedAt ?? DateTime.now()).compareTo(a.dispensedAt ?? DateTime.now()));
  }

  List<HospitalPharmacyDispenseModel> get _missedDispenses {
    return _dispenses.where((d) => d.status == MedicationDispenseStatus.missed).toList()
      ..sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('صيدلية المستشفى الداخلية'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'المجدولة', icon: Icon(Icons.schedule)),
            Tab(text: 'المصروفة اليوم', icon: Icon(Icons.check_circle)),
            Tab(text: 'الفائتة', icon: Icon(Icons.error)),
          ],
        ),
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              if (value == 'status') {
                _showStatusFilter();
              } else if (value == 'clear') {
                setState(() => _filterStatus = null);
                _loadDispenses();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'status',
                child: Text('فلترة حسب الحالة'),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Text('إزالة الفلاتر'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MedicationSchedulesScreen()),
            ),
            tooltip: 'جدولة الأدوية',
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MedicationDispenseHistoryScreen()),
            ),
            tooltip: 'سجل الأدوية',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDispenses,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildScheduledTab(),
          _buildDispensedTab(),
          _buildMissedTab(),
        ],
      ),
    );
  }

  Widget _buildScheduledTab() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadDispenses,
            child: _scheduledDispenses.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.medication_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'لا توجد أدوية مجدولة',
                            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _scheduledDispenses.length,
                    itemBuilder: (context, index) {
                      final dispense = _scheduledDispenses[index];
                      return _buildDispenseCard(dispense);
                    },
                  ),
          );
  }

  Widget _buildDispensedTab() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadDispenses,
            child: _dispensedToday.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'لا توجد أدوية مصروفة اليوم',
                            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _dispensedToday.length,
                    itemBuilder: (context, index) {
                      final dispense = _dispensedToday[index];
                      return _buildDispenseCard(dispense);
                    },
                  ),
          );
  }

  Widget _buildMissedTab() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadDispenses,
            child: _missedDispenses.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'لا توجد أدوية فائتة',
                            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _missedDispenses.length,
                    itemBuilder: (context, index) {
                      final dispense = _missedDispenses[index];
                      return _buildDispenseCard(dispense);
                    },
                  ),
          );
  }

  Widget _buildDispenseCard(HospitalPharmacyDispenseModel dispense) {
    final dateFormat = DateFormat('HH:mm', 'ar');
    final dateFormatFull = DateFormat('yyyy-MM-dd HH:mm', 'ar');

    final statusColor = {
      MedicationDispenseStatus.scheduled: Colors.blue,
      MedicationDispenseStatus.dispensed: Colors.green,
      MedicationDispenseStatus.missed: Colors.red,
      MedicationDispenseStatus.cancelled: Colors.grey,
    }[dispense.status]!;

    final statusText = {
      MedicationDispenseStatus.scheduled: 'مجدولة',
      MedicationDispenseStatus.dispensed: 'مصروفة',
      MedicationDispenseStatus.missed: 'فائتة',
      MedicationDispenseStatus.cancelled: 'ملغاة',
    }[dispense.status]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: dispense.isOverdue || dispense.isDueSoon ? 4 : 2,
      color: dispense.isOverdue
          ? Colors.red.shade50
          : dispense.isDueSoon
              ? Colors.orange.shade50
              : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.2),
          child: Icon(
            dispense.status == MedicationDispenseStatus.dispensed
                ? Icons.check_circle
                : dispense.status == MedicationDispenseStatus.missed
                    ? Icons.error
                    : Icons.medication,
            color: statusColor,
          ),
        ),
        title: Text(
          dispense.medicationName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('المريض: ${dispense.patientName}'),
            if (dispense.bedId != null) Text('السرير: ${dispense.bedId}'),
            Text('الجرعة: ${dispense.dosage} - ${dispense.frequency}'),
            Text('الكمية: ${dispense.quantity}'),
            Text(
              'الوقت المحدد: ${dateFormat.format(dispense.scheduledTime)}',
              style: TextStyle(
                color: dispense.isOverdue
                    ? Colors.red
                    : dispense.isDueSoon
                        ? Colors.orange
                        : null,
                fontWeight: dispense.isOverdue || dispense.isDueSoon
                    ? FontWeight.bold
                    : null,
              ),
            ),
            if (dispense.dispensedAt != null)
              Text(
                'تم الصرف: ${dateFormatFull.format(dispense.dispensedAt!)}',
                style: const TextStyle(color: Colors.green),
              ),
            if (dispense.dispensedBy != null)
              Text('صرف بواسطة: ${dispense.dispensedBy}'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Chip(
              label: Text(statusText, style: const TextStyle(fontSize: 12)),
              backgroundColor: statusColor.withValues(alpha: 0.2),
              labelStyle: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
            ),
            if (dispense.status == MedicationDispenseStatus.scheduled) ...[
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => _dispenseMedication(dispense),
                icon: const Icon(Icons.check, size: 16),
                label: const Text('صرف'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ],
        ),
        onTap: () => _viewDispenseDetails(dispense),
      ),
    );
  }

  Future<void> _dispenseMedication(HospitalPharmacyDispenseModel dispense) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('صرف الدواء'),
        content: Text('هل تريد صرف ${dispense.medicationName} للمريض ${dispense.patientName}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('صرف'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final user = AuthHelper.getCurrentUser(context);
      await _dataService.updateDispenseStatus(
        dispense.id,
        MedicationDispenseStatus.dispensed,
        dispensedBy: user?.name,
      );

      await _loadDispenses();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم صرف الدواء بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في صرف الدواء: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _viewDispenseDetails(HospitalPharmacyDispenseModel dispense) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DispenseMedicationScreen(dispense: dispense),
      ),
    ).then((_) => _loadDispenses());
  }

  void _showStatusFilter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('فلترة حسب الحالة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<MedicationDispenseStatus?>(
              title: const Text('جميع الحالات'),
              value: null,
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() => _filterStatus = value);
                Navigator.pop(context);
                _loadDispenses();
              },
            ),
            RadioListTile<MedicationDispenseStatus?>(
              title: const Text('مجدولة'),
              value: MedicationDispenseStatus.scheduled,
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() => _filterStatus = value);
                Navigator.pop(context);
                _loadDispenses();
              },
            ),
            RadioListTile<MedicationDispenseStatus?>(
              title: const Text('مصروفة'),
              value: MedicationDispenseStatus.dispensed,
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() => _filterStatus = value);
                Navigator.pop(context);
                _loadDispenses();
              },
            ),
            RadioListTile<MedicationDispenseStatus?>(
              title: const Text('فائتة'),
              value: MedicationDispenseStatus.missed,
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() => _filterStatus = value);
                Navigator.pop(context);
                _loadDispenses();
              },
            ),
          ],
        ),
      ),
    );
  }
}

