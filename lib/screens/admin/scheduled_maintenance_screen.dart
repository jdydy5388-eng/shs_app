import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/maintenance_models.dart';
import '../../services/data_service.dart';
import 'create_scheduled_maintenance_screen.dart';

class ScheduledMaintenanceScreen extends StatefulWidget {
  const ScheduledMaintenanceScreen({super.key});

  @override
  State<ScheduledMaintenanceScreen> createState() => _ScheduledMaintenanceScreenState();
}

class _ScheduledMaintenanceScreenState extends State<ScheduledMaintenanceScreen> {
  final DataService _dataService = DataService();
  List<ScheduledMaintenanceModel> _scheduledMaintenances = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadScheduledMaintenances();
  }

  Future<void> _loadScheduledMaintenances() async {
    setState(() => _isLoading = true);
    try {
      final maintenances = await _dataService.getScheduledMaintenances();
      setState(() {
        _scheduledMaintenances = maintenances.cast<ScheduledMaintenanceModel>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _scheduledMaintenances.isEmpty
              ? const Center(child: Text('لا توجد صيانة دورية مجدولة'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _scheduledMaintenances.length,
                  itemBuilder: (context, index) {
                    return _buildScheduledMaintenanceCard(_scheduledMaintenances[index]);
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateScheduledMaintenanceScreen()),
        ).then((_) => _loadScheduledMaintenances()),
        icon: const Icon(Icons.add),
        label: const Text('جدولة صيانة'),
      ),
    );
  }

  Widget _buildScheduledMaintenanceCard(ScheduledMaintenanceModel maintenance) {
    final dateFormat = DateFormat('yyyy-MM-dd', 'ar');
    final isOverdue = maintenance.nextDueDate.isBefore(DateTime.now());
    
    final frequencyText = {
      ScheduledMaintenanceFrequency.daily: 'يومي',
      ScheduledMaintenanceFrequency.weekly: 'أسبوعي',
      ScheduledMaintenanceFrequency.monthly: 'شهري',
      ScheduledMaintenanceFrequency.quarterly: 'ربع سنوي',
      ScheduledMaintenanceFrequency.semiAnnual: 'نصف سنوي',
      ScheduledMaintenanceFrequency.annual: 'سنوي',
      ScheduledMaintenanceFrequency.custom: 'مخصص',
    }[maintenance.frequency]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isOverdue ? Colors.red.shade50 : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isOverdue ? Colors.red : Colors.blue,
          child: Icon(
            isOverdue ? Icons.warning : Icons.schedule,
            color: Colors.white,
          ),
        ),
        title: Text(maintenance.equipmentName ?? maintenance.equipmentId),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${maintenance.maintenanceType} - $frequencyText'),
            Text('تاريخ الاستحقاق: ${dateFormat.format(maintenance.nextDueDate)}'),
            if (isOverdue)
              Text(
                'متأخر!',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
          ],
        ),
        trailing: Text(_getStatusText(maintenance.status)),
      ),
    );
  }

  String _getStatusText(ScheduledMaintenanceStatus status) {
    return {
      ScheduledMaintenanceStatus.scheduled: 'مجدول',
      ScheduledMaintenanceStatus.inProgress: 'قيد التنفيذ',
      ScheduledMaintenanceStatus.completed: 'مكتمل',
      ScheduledMaintenanceStatus.skipped: 'تم التخطي',
      ScheduledMaintenanceStatus.cancelled: 'ملغى',
    }[status]!;
  }
}

