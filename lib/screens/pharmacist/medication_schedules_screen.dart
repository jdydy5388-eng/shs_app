import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/hospital_pharmacy_model.dart';
import '../../models/prescription_model.dart';
import '../../services/data_service.dart';
import 'create_medication_schedule_screen.dart';

class MedicationSchedulesScreen extends StatefulWidget {
  const MedicationSchedulesScreen({super.key});

  @override
  State<MedicationSchedulesScreen> createState() => _MedicationSchedulesScreenState();
}

class _MedicationSchedulesScreenState extends State<MedicationSchedulesScreen> {
  final DataService _dataService = DataService();
  List<MedicationScheduleModel> _schedules = [];
  bool _isLoading = true;
  bool _showActiveOnly = true;

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    setState(() => _isLoading = true);
    try {
      final schedules = await _dataService.getMedicationSchedules(
        isActive: _showActiveOnly ? true : null,
      );
      setState(() {
        _schedules = schedules.cast<MedicationScheduleModel>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل الجداول: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('جدولة الأدوية'),
        actions: [
          Switch(
            value: _showActiveOnly,
            onChanged: (value) {
              setState(() => _showActiveOnly = value);
              _loadSchedules();
            },
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('نشطة فقط'),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _createSchedule(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSchedules,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSchedules,
              child: _schedules.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'لا توجد جداول أدوية',
                              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _schedules.length,
                      itemBuilder: (context, index) {
                        final schedule = _schedules[index];
                        return _buildScheduleCard(schedule);
                      },
                    ),
            ),
    );
  }

  Widget _buildScheduleCard(MedicationScheduleModel schedule) {
    final dateFormat = DateFormat('yyyy-MM-dd', 'ar');
    final timeFormat = DateFormat('HH:mm', 'ar');

    final scheduleTypeText = {
      MedicationScheduleType.scheduled: 'مجدولة',
      MedicationScheduleType.prn: 'عند الحاجة',
      MedicationScheduleType.stat: 'فورية',
    }[schedule.scheduleType]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: schedule.isActive ? null : Colors.grey.shade100,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: schedule.isActive ? Colors.blue : Colors.grey,
          child: Icon(
            schedule.isActive ? Icons.schedule : Icons.schedule_outlined,
            color: Colors.white,
          ),
        ),
        title: Text(
          schedule.medicationName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('المريض: ${schedule.patientName}'),
            if (schedule.bedId != null) Text('السرير: ${schedule.bedId}'),
            Text('الجرعة: ${schedule.dosage} - ${schedule.frequency}'),
            Text('النوع: $scheduleTypeText'),
            Text('من: ${dateFormat.format(schedule.startDate)}'),
            if (schedule.endDate != null)
              Text('إلى: ${dateFormat.format(schedule.endDate!)}'),
            if (schedule.scheduledTimes.isNotEmpty)
              Text(
                'الأوقات: ${schedule.scheduledTimes.map((t) => timeFormat.format(t)).join(', ')}',
                style: const TextStyle(fontSize: 12),
              ),
            if (!schedule.isActive)
              const Text(
                'غير نشط',
                style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
              ),
          ],
        ),
        trailing: schedule.isActive
            ? const Icon(Icons.arrow_forward_ios, size: 16)
            : const Icon(Icons.block, color: Colors.grey),
        onTap: () {
          // يمكن إضافة شاشة تفاصيل الجدول لاحقاً
        },
      ),
    );
  }

  void _createSchedule() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateMedicationScheduleScreen()),
    ).then((_) => _loadSchedules());
  }
}

