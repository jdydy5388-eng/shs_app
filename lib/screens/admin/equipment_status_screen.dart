import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/maintenance_models.dart';
import '../../services/data_service.dart';
import 'create_equipment_status_screen.dart';

class EquipmentStatusScreen extends StatefulWidget {
  const EquipmentStatusScreen({super.key});

  @override
  State<EquipmentStatusScreen> createState() => _EquipmentStatusScreenState();
}

class _EquipmentStatusScreenState extends State<EquipmentStatusScreen> {
  final DataService _dataService = DataService();
  List<EquipmentStatusModel> _equipmentStatuses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEquipmentStatuses();
  }

  Future<void> _loadEquipmentStatuses() async {
    setState(() => _isLoading = true);
    try {
      final statuses = await _dataService.getEquipmentStatuses();
      setState(() {
        _equipmentStatuses = statuses.cast<EquipmentStatusModel>();
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
          : _equipmentStatuses.isEmpty
              ? const Center(child: Text('لا توجد بيانات حالة معدات'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _equipmentStatuses.length,
                  itemBuilder: (context, index) {
                    return _buildEquipmentStatusCard(_equipmentStatuses[index]);
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateEquipmentStatusScreen()),
        ).then((_) => _loadEquipmentStatuses()),
        icon: const Icon(Icons.add),
        label: const Text('إضافة حالة معدات'),
      ),
    );
  }

  Widget _buildEquipmentStatusCard(EquipmentStatusModel status) {
    final dateFormat = DateFormat('yyyy-MM-dd', 'ar');
    
    final conditionColor = {
      EquipmentCondition.excellent: Colors.green,
      EquipmentCondition.good: Colors.blue,
      EquipmentCondition.fair: Colors.orange,
      EquipmentCondition.poor: Colors.red,
      EquipmentCondition.critical: Colors.red.shade900,
      EquipmentCondition.outOfService: Colors.grey,
    }[status.condition]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: conditionColor.withValues(alpha: 0.2),
          child: Icon(Icons.precision_manufacturing, color: conditionColor),
        ),
        title: Text(status.equipmentName ?? status.equipmentId),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('آخر صيانة: ${dateFormat.format(status.lastMaintenanceDate)}'),
            if (status.nextMaintenanceDate != null)
              Text('صيانة قادمة: ${dateFormat.format(status.nextMaintenanceDate!)}'),
            if (status.totalMaintenanceCount != null)
              Text('عدد مرات الصيانة: ${status.totalMaintenanceCount}'),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: conditionColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _getConditionText(status.condition),
            style: TextStyle(
              fontSize: 12,
              color: conditionColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  String _getConditionText(EquipmentCondition condition) {
    return {
      EquipmentCondition.excellent: 'ممتاز',
      EquipmentCondition.good: 'جيد',
      EquipmentCondition.fair: 'مقبول',
      EquipmentCondition.poor: 'ضعيف',
      EquipmentCondition.critical: 'حرج',
      EquipmentCondition.outOfService: 'خارج الخدمة',
    }[condition]!;
  }
}

