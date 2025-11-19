import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/medical_inventory_model.dart';
import '../../services/data_service.dart';

class MaintenanceScheduleScreen extends StatefulWidget {
  final String? equipmentId;

  const MaintenanceScheduleScreen({super.key, this.equipmentId});

  @override
  State<MaintenanceScheduleScreen> createState() => _MaintenanceScheduleScreenState();
}

class _MaintenanceScheduleScreenState extends State<MaintenanceScheduleScreen> {
  final DataService _dataService = DataService();
  List<MaintenanceRecordModel> _records = [];
  List<MedicalInventoryItemModel> _equipment = [];
  bool _isLoading = true;
  String? _selectedEquipmentId;

  @override
  void initState() {
    super.initState();
    _selectedEquipmentId = widget.equipmentId;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final equipment = await _dataService.getMedicalInventory(type: InventoryItemType.equipment);
      final records = await _dataService.getMaintenanceRecords(
        equipmentId: _selectedEquipmentId,
      );

      setState(() {
        _equipment = equipment.cast<MedicalInventoryItemModel>();
        _records = records.cast<MaintenanceRecordModel>();
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

  List<MedicalInventoryItemModel> get _needsMaintenance {
    return _equipment.where((e) => e.needsMaintenance).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('جدولة الصيانة'),
        actions: [
          if (_selectedEquipmentId == null)
            PopupMenuButton<String?>(
              icon: const Icon(Icons.filter_list),
              onSelected: (value) {
                if (value == 'all') {
                  setState(() => _selectedEquipmentId = null);
                  _loadData();
                } else if (value == 'needs') {
                  // عرض المعدات التي تحتاج صيانة
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'all',
                  child: Text('جميع المعدات'),
                ),
                const PopupMenuItem(
                  value: 'needs',
                  child: Text('تحتاج صيانة'),
                ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_needsMaintenance.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.orange.shade50,
                    child: Row(
                      children: [
                        const Icon(Icons.warning, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_needsMaintenance.length} معدات تحتاج صيانة',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: _selectedEquipmentId == null
                      ? _buildEquipmentList()
                      : _buildMaintenanceRecords(),
                ),
              ],
            ),
    );
  }

  Widget _buildEquipmentList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _equipment.length,
      itemBuilder: (context, index) {
        final equipment = _equipment[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: equipment.needsMaintenance ? Colors.orange.shade50 : null,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: equipment.needsMaintenance
                  ? Colors.orange
                  : Colors.blue,
              child: const Icon(Icons.build, color: Colors.white),
            ),
            title: Text(equipment.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (equipment.nextMaintenanceDate != null)
                  Text(
                    'صيانة قادمة: ${DateFormat('yyyy-MM-dd', 'ar').format(equipment.nextMaintenanceDate!)}',
                    style: TextStyle(
                      color: equipment.needsMaintenance ? Colors.orange : null,
                      fontWeight: equipment.needsMaintenance ? FontWeight.bold : null,
                    ),
                  ),
                if (equipment.lastMaintenanceDate != null)
                  Text(
                    'آخر صيانة: ${DateFormat('yyyy-MM-dd', 'ar').format(equipment.lastMaintenanceDate!)}',
                  ),
              ],
            ),
            trailing: equipment.needsMaintenance
                ? const Icon(Icons.warning, color: Colors.orange)
                : const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              setState(() => _selectedEquipmentId = equipment.id);
              _loadData();
            },
          ),
        );
      },
    );
  }

  Widget _buildMaintenanceRecords() {
    if (_records.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.build_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'لا توجد سجلات صيانة',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _records.length,
      itemBuilder: (context, index) {
        final record = _records[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: {
                'scheduled': Colors.blue,
                'repair': Colors.red,
                'inspection': Colors.green,
              }[record.maintenanceType]?.withValues(alpha: 0.2) ?? Colors.grey,
              child: Icon(
                {
                  'scheduled': Icons.schedule,
                  'repair': Icons.build,
                  'inspection': Icons.search,
                }[record.maintenanceType] ?? Icons.build,
              ),
            ),
            title: Text(record.equipmentName),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('النوع: ${record.maintenanceType}'),
                Text('التاريخ: ${DateFormat('yyyy-MM-dd', 'ar').format(record.maintenanceDate)}'),
                if (record.performedBy != null) Text('تم بواسطة: ${record.performedBy}'),
                if (record.cost != null) Text('التكلفة: ${record.cost!.toStringAsFixed(2)} ريال'),
                if (record.nextMaintenanceDate != null)
                  Text(
                    'الصيانة القادمة: ${DateFormat('yyyy-MM-dd', 'ar').format(record.nextMaintenanceDate!)}',
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

