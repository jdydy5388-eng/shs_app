import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/hospital_pharmacy_model.dart';
import '../../services/data_service.dart';

class MedicationDispenseHistoryScreen extends StatefulWidget {
  const MedicationDispenseHistoryScreen({super.key});

  @override
  State<MedicationDispenseHistoryScreen> createState() => _MedicationDispenseHistoryScreenState();
}

class _MedicationDispenseHistoryScreenState extends State<MedicationDispenseHistoryScreen> {
  final DataService _dataService = DataService();
  List<HospitalPharmacyDispenseModel> _history = [];
  bool _isLoading = true;
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    _fromDate = DateTime.now().subtract(const Duration(days: 7));
    _toDate = DateTime.now();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final history = await _dataService.getHospitalPharmacyDispenses(
        from: _fromDate,
        to: _toDate,
      );
      setState(() {
        _history = history.cast<HospitalPharmacyDispenseModel>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل السجل: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd', 'ar');

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل الأدوية المصروفة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistory,
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
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadHistory,
                    child: _history.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.history_outlined,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'لا توجد سجلات في الفترة المحددة',
                                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _history.length,
                            itemBuilder: (context, index) {
                              final dispense = _history[index];
                              return _buildHistoryCard(dispense);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(HospitalPharmacyDispenseModel dispense) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm', 'ar');

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
            Text('الجرعة: ${dispense.dosage} - ${dispense.frequency}'),
            Text('الكمية: ${dispense.quantity}'),
            Text('الوقت المحدد: ${dateFormat.format(dispense.scheduledTime)}'),
            if (dispense.dispensedAt != null)
              Text(
                'وقت الصرف: ${dateFormat.format(dispense.dispensedAt!)}',
                style: const TextStyle(color: Colors.green),
              ),
            if (dispense.dispensedBy != null)
              Text('صرف بواسطة: ${dispense.dispensedBy}'),
          ],
        ),
        trailing: Chip(
          label: Text(statusText, style: const TextStyle(fontSize: 12)),
          backgroundColor: statusColor.withValues(alpha: 0.2),
          labelStyle: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final from = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now().subtract(const Duration(days: 7)),
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
    _loadHistory();
  }
}

