import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/medical_inventory_model.dart';
import '../../services/data_service.dart';
import '../../utils/auth_helper.dart';
import 'maintenance_schedule_screen.dart';

class MedicalInventoryItemDetailsScreen extends StatefulWidget {
  final MedicalInventoryItemModel item;

  const MedicalInventoryItemDetailsScreen({super.key, required this.item});

  @override
  State<MedicalInventoryItemDetailsScreen> createState() => _MedicalInventoryItemDetailsScreenState();
}

class _MedicalInventoryItemDetailsScreenState extends State<MedicalInventoryItemDetailsScreen> {
  final DataService _dataService = DataService();
  final Uuid _uuid = const Uuid();
  late MedicalInventoryItemModel _item;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd', 'ar');

    final typeText = {
      InventoryItemType.equipment: 'معدات',
      InventoryItemType.supplies: 'مستلزمات',
      InventoryItemType.consumables: 'مواد استهلاكية',
    }[_item.type]!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل العنصر'),
        actions: [
          if (_item.type == InventoryItemType.equipment)
            IconButton(
              icon: const Icon(Icons.build),
              onPressed: () => _viewMaintenance(),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderCard(typeText, dateFormat),
                  const SizedBox(height: 16),
                  _buildQuantityCard(),
                  if (_item.type == InventoryItemType.equipment) ...[
                    const SizedBox(height: 16),
                    _buildEquipmentInfoCard(),
                  ],
                  if (_item.supplierName != null) ...[
                    const SizedBox(height: 16),
                    _buildSupplierCard(),
                  ],
                  const SizedBox(height: 16),
                  _buildActionsCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard(String typeText, DateFormat dateFormat) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _item.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Chip(
                  label: Text(typeText),
                  backgroundColor: {
                    InventoryItemType.equipment: Colors.blue,
                    InventoryItemType.supplies: Colors.green,
                    InventoryItemType.consumables: Colors.orange,
                  }[_item.type]!.withValues(alpha: 0.2),
                ),
              ],
            ),
            if (_item.category != null) ...[
              const SizedBox(height: 8),
              Text('الفئة: ${_item.category}'),
            ],
            if (_item.description != null) ...[
              const SizedBox(height: 8),
              Text(_item.description!),
            ],
            if (_item.location != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16),
                  const SizedBox(width: 4),
                  Text('الموقع: ${_item.location}'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityCard() {
    final dateFormat = DateFormat('yyyy-MM-dd', 'ar');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'المخزون',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('الكمية الحالية:'),
                Text(
                  '${_item.quantity} ${_item.unit ?? ''}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            if (_item.minStockLevel != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('الحد الأدنى:'),
                  Text(
                    '${_item.minStockLevel} ${_item.unit ?? ''}',
                    style: TextStyle(
                      color: _item.isLowStock ? Colors.orange : Colors.grey,
                      fontWeight: _item.isLowStock ? FontWeight.bold : null,
                    ),
                  ),
                ],
              ),
            ],
            if (_item.expiryDate != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('انتهاء الصلاحية:'),
                  Text(
                    dateFormat.format(_item.expiryDate!),
                    style: TextStyle(
                      color: _item.isExpired
                          ? Colors.red
                          : _item.isExpiringSoon
                              ? Colors.orange
                              : null,
                      fontWeight: _item.isExpired || _item.isExpiringSoon
                          ? FontWeight.bold
                          : null,
                    ),
                  ),
                ],
              ),
            ],
            if (_item.isLowStock || _item.isExpired)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _item.isExpired
                      ? Colors.red.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _item.isExpired ? Icons.error : Icons.warning,
                      color: _item.isExpired ? Colors.red : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _item.isExpired
                            ? 'منتهي الصلاحية!'
                            : 'المخزون منخفض!',
                        style: TextStyle(
                          color: _item.isExpired ? Colors.red : Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEquipmentInfoCard() {
    final dateFormat = DateFormat('yyyy-MM-dd', 'ar');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'معلومات المعدات',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_item.manufacturer != null)
              _buildInfoRow('الشركة المصنعة', _item.manufacturer!),
            if (_item.model != null) _buildInfoRow('الموديل', _item.model!),
            if (_item.serialNumber != null)
              _buildInfoRow('الرقم التسلسلي', _item.serialNumber!),
            if (_item.status != null)
              _buildInfoRow(
                'الحالة',
                {
                  EquipmentStatus.available: 'متاحة',
                  EquipmentStatus.inUse: 'قيد الاستخدام',
                  EquipmentStatus.maintenance: 'صيانة',
                  EquipmentStatus.outOfOrder: 'معطلة',
                }[_item.status]!,
              ),
            if (_item.purchaseDate != null)
              _buildInfoRow('تاريخ الشراء', dateFormat.format(_item.purchaseDate!)),
            if (_item.nextMaintenanceDate != null) ...[
              _buildInfoRow(
                'الصيانة القادمة',
                dateFormat.format(_item.nextMaintenanceDate!),
              ),
              if (_item.needsMaintenance)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.build, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'يحتاج صيانة!',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSupplierCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'المورد',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(_item.supplierName!),
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
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _adjustQuantity,
                icon: const Icon(Icons.edit),
                label: const Text('تعديل الكمية'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            if (_item.type == InventoryItemType.equipment) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _recordMaintenance,
                  icon: const Icon(Icons.build),
                  label: const Text('تسجيل صيانة'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _adjustQuantity() async {
    final quantityController = TextEditingController(text: _item.quantity.toString());

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل الكمية'),
        content: TextField(
          controller: quantityController,
          decoration: const InputDecoration(
            labelText: 'الكمية الجديدة',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (quantityController.text.trim().isEmpty ||
                  int.tryParse(quantityController.text.trim()) == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('يرجى إدخال رقم صحيح')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (result != true) return;

    try {
      final newQuantity = int.parse(quantityController.text.trim());
      await _dataService.updateMedicalInventoryItem(
        _item.id,
        quantity: newQuantity,
      );

      setState(() {
        _item = MedicalInventoryItemModel(
          id: _item.id,
          name: _item.name,
          type: _item.type,
          category: _item.category,
          description: _item.description,
          quantity: newQuantity,
          minStockLevel: _item.minStockLevel,
          unit: _item.unit,
          unitPrice: _item.unitPrice,
          manufacturer: _item.manufacturer,
          model: _item.model,
          serialNumber: _item.serialNumber,
          purchaseDate: _item.purchaseDate,
          expiryDate: _item.expiryDate,
          location: _item.location,
          status: _item.status,
          lastMaintenanceDate: _item.lastMaintenanceDate,
          nextMaintenanceDate: _item.nextMaintenanceDate,
          supplierId: _item.supplierId,
          supplierName: _item.supplierName,
          createdAt: _item.createdAt,
          updatedAt: DateTime.now(),
        );
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث الكمية بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في التحديث: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _recordMaintenance() async {
    final descriptionController = TextEditingController();
    final costController = TextEditingController();
    String maintenanceType = 'scheduled';
    DateTime? nextMaintenanceDate;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('تسجيل صيانة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: maintenanceType,
                  decoration: const InputDecoration(
                    labelText: 'نوع الصيانة',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'scheduled', child: Text('مجدولة')),
                    DropdownMenuItem(value: 'repair', child: Text('إصلاح')),
                    DropdownMenuItem(value: 'inspection', child: Text('فحص')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => maintenanceType = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'الوصف',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: costController,
                  decoration: const InputDecoration(
                    labelText: 'التكلفة (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('تاريخ الصيانة القادمة'),
                  subtitle: Text(nextMaintenanceDate != null
                      ? DateFormat('yyyy-MM-dd', 'ar').format(nextMaintenanceDate!)
                      : 'غير محدد'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: nextMaintenanceDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setState(() => nextMaintenanceDate = date);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    try {
      final record = MaintenanceRecordModel(
        id: _uuid.v4(),
        equipmentId: _item.id,
        equipmentName: _item.name,
        maintenanceDate: DateTime.now(),
        maintenanceType: maintenanceType,
        description: descriptionController.text.trim().isEmpty
            ? null
            : descriptionController.text.trim(),
        performedBy: AuthHelper.getCurrentUser(context)?.name,
        cost: costController.text.trim().isEmpty
            ? null
            : double.tryParse(costController.text.trim()),
        nextMaintenanceDate: nextMaintenanceDate,
        createdAt: DateTime.now(),
      );

      await _dataService.createMaintenanceRecord(record);

      if (nextMaintenanceDate != null) {
        await _dataService.updateMedicalInventoryItem(
          _item.id,
          nextMaintenanceDate: nextMaintenanceDate,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تسجيل الصيانة بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تسجيل الصيانة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _viewMaintenance() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MaintenanceScheduleScreen(equipmentId: _item.id),
      ),
    );
  }
}

