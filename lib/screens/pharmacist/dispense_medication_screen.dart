import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/hospital_pharmacy_model.dart';
import '../../services/data_service.dart';
import '../../utils/auth_helper.dart';

class DispenseMedicationScreen extends StatefulWidget {
  final HospitalPharmacyDispenseModel dispense;

  const DispenseMedicationScreen({super.key, required this.dispense});

  @override
  State<DispenseMedicationScreen> createState() => _DispenseMedicationScreenState();
}

class _DispenseMedicationScreenState extends State<DispenseMedicationScreen> {
  final DataService _dataService = DataService();
  late HospitalPharmacyDispenseModel _dispense;
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _dispense = widget.dispense;
    _notesController.text = _dispense.notes ?? '';
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm', 'ar');

    final statusColor = {
      MedicationDispenseStatus.scheduled: Colors.blue,
      MedicationDispenseStatus.dispensed: Colors.green,
      MedicationDispenseStatus.missed: Colors.red,
      MedicationDispenseStatus.cancelled: Colors.grey,
    }[_dispense.status]!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل صرف الدواء'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(statusColor, dateFormat),
            const SizedBox(height: 16),
            _buildPatientInfoCard(),
            const SizedBox(height: 16),
            _buildMedicationInfoCard(),
            const SizedBox(height: 16),
            _buildScheduleInfoCard(dateFormat),
            const SizedBox(height: 16),
            if (_dispense.status == MedicationDispenseStatus.scheduled)
              _buildActionsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(Color statusColor, DateFormat dateFormat) {
    final statusText = {
      MedicationDispenseStatus.scheduled: 'مجدولة',
      MedicationDispenseStatus.dispensed: 'مصروفة',
      MedicationDispenseStatus.missed: 'فائتة',
      MedicationDispenseStatus.cancelled: 'ملغاة',
    }[_dispense.status]!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _dispense.medicationName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('المريض: ${_dispense.patientName}'),
                ],
              ),
            ),
            Chip(
              label: Text(statusText),
              backgroundColor: statusColor.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'معلومات المريض',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('اسم المريض', _dispense.patientName),
            if (_dispense.bedId != null)
              _buildInfoRow('رقم السرير', _dispense.bedId!),
            if (_dispense.roomId != null)
              _buildInfoRow('رقم الغرفة', _dispense.roomId!),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicationInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'معلومات الدواء',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('اسم الدواء', _dispense.medicationName),
            _buildInfoRow('الجرعة', _dispense.dosage),
            _buildInfoRow('التكرار', _dispense.frequency),
            _buildInfoRow('الكمية', _dispense.quantity.toString()),
            if (_dispense.notes != null)
              _buildInfoRow('ملاحظات', _dispense.notes!),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleInfoCard(DateFormat dateFormat) {
    final scheduleTypeText = {
      MedicationScheduleType.scheduled: 'مجدولة',
      MedicationScheduleType.prn: 'عند الحاجة',
      MedicationScheduleType.stat: 'فورية',
    }[_dispense.scheduleType]!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'معلومات الجدولة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('نوع الجدولة', scheduleTypeText),
            _buildInfoRow('الوقت المحدد', dateFormat.format(_dispense.scheduledTime)),
            if (_dispense.dispensedAt != null)
              _buildInfoRow('وقت الصرف', dateFormat.format(_dispense.dispensedAt!)),
            if (_dispense.dispensedBy != null)
              _buildInfoRow('صرف بواسطة', _dispense.dispensedBy!),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'ملاحظات (اختياري)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _dispenseMedication,
                icon: const Icon(Icons.check),
                label: const Text('صرف الدواء'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _markAsMissed,
                icon: const Icon(Icons.close),
                label: const Text('تحديد كفائت'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _dispenseMedication() async {
    try {
      final user = AuthHelper.getCurrentUser(context);
      await _dataService.updateDispenseStatus(
        _dispense.id,
        MedicationDispenseStatus.dispensed,
        dispensedBy: user?.name,
      );

      if (_notesController.text.trim().isNotEmpty) {
        // يمكن إضافة تحديث الملاحظات لاحقاً
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم صرف الدواء بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
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

  Future<void> _markAsMissed() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تحديد كفائت'),
        content: const Text('هل تريد تحديد هذا الدواء كفائت؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _dataService.updateDispenseStatus(
        _dispense.id,
        MedicationDispenseStatus.missed,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديد الدواء كفائت'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

