import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/medication_inventory_model.dart';
import '../../providers/auth_provider_local.dart';
import '../../services/data_service.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final DataService _dataService = DataService();
  List<MedicationInventoryModel> _items = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProviderLocal>(context, listen: false);
      final pharmacyId = authProvider.currentUser?.id ?? '';
      final items = await _dataService.getInventory(pharmacyId: pharmacyId);
      setState(() {
        _items = items.cast<MedicationInventoryModel>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل المخزون: $e')),
        );
      }
    }
  }

  List<MedicationInventoryModel> get _filteredItems {
    if (_searchQuery.isEmpty) return _items;
    return _items.where((item) {
      return item.medicationName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (item.manufacturer?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المخزون واقتراح البدائل'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInventory,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'بحث في المخزون',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildInventoryList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMedicationDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildInventoryList() {
    final filtered = _filteredItems;

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                _searchQuery.isEmpty
                    ? 'لا توجد أدوية في المخزون'
                    : 'لا توجد نتائج',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInventory,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final item = filtered[index];
          return _buildInventoryCard(item);
        },
      ),
    );
  }

  Widget _buildInventoryCard(MedicationInventoryModel item) {
    Color statusColor = Colors.green;
    String statusText = 'متوفر';
    if (item.isOutOfStock) {
      statusColor = Colors.red;
      statusText = 'نفد';
    } else if (item.isLowStock) {
      statusColor = Colors.orange;
      statusText = 'مخزون منخفض';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.2),
          child: Icon(
            Icons.medication,
            color: statusColor,
          ),
        ),
        title: Text(
          item.medicationName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الكمية: ${item.quantity}'),
            Text('السعر: ${item.price.toStringAsFixed(2)} ر.س'),
            Chip(
              label: Text(statusText, style: const TextStyle(fontSize: 12)),
              backgroundColor: statusColor.withValues(alpha: 0.2),
              labelStyle: TextStyle(color: statusColor),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.manufacturer != null)
                  Text('الشركة المصنعة: ${item.manufacturer}'),
                if (item.expiryDate != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'تاريخ الانتهاء: ${_formatDate(item.expiryDate!)}',
                    style: TextStyle(
                      color: item.isExpired ? Colors.red : null,
                      fontWeight: item.isExpired ? FontWeight.bold : null,
                    ),
                  ),
                ],
                if (item.batchNumber != null) ...[
                  const SizedBox(height: 8),
                  Text('رقم الدفعة: ${item.batchNumber}'),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('تعديل'),
                      onPressed: () => _showEditMedicationDialog(item),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text('حذف', style: TextStyle(color: Colors.red)),
                      onPressed: () => _deleteMedication(item.id),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddMedicationDialog() async {
    final nameController = TextEditingController();
    final quantityController = TextEditingController();
    final priceController = TextEditingController();
    final manufacturerController = TextEditingController();
    final batchNumberController = TextEditingController();
    DateTime? expiryDate;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('إضافة دواء جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم الدواء *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: quantityController,
                  decoration: const InputDecoration(
                    labelText: 'الكمية *',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(
                    labelText: 'السعر *',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: manufacturerController,
                  decoration: const InputDecoration(
                    labelText: 'الشركة المصنعة',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: batchNumberController,
                  decoration: const InputDecoration(
                    labelText: 'رقم الدفعة',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: Text(expiryDate == null
                      ? 'تاريخ الانتهاء (اختياري)'
                      : _formatDate(expiryDate!)),
                  trailing: expiryDate != null
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => expiryDate = null),
                        )
                      : null,
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                    );
                    if (date != null) {
                      setState(() => expiryDate = date);
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
              onPressed: () {
                if (nameController.text.trim().isEmpty ||
                    quantityController.text.trim().isEmpty ||
                    priceController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى ملء جميع الحقول المطلوبة')),
                  );
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      try {
        final authProvider = Provider.of<AuthProviderLocal>(context, listen: false);
        final pharmacyId = authProvider.currentUser?.id ?? '';
        
        if (pharmacyId.isEmpty) {
          throw Exception('لا يمكن تحديد هوية الصيدلية');
        }

        final item = MedicationInventoryModel(
          id: _dataService.generateId(),
          pharmacyId: pharmacyId,
          medicationName: nameController.text.trim(),
          medicationId: '', // يمكن تركها فارغة أو توليد ID
          quantity: int.tryParse(quantityController.text.trim()) ?? 0,
          price: double.tryParse(priceController.text.trim()) ?? 0.0,
          manufacturer: manufacturerController.text.trim().isEmpty 
              ? null 
              : manufacturerController.text.trim(),
          expiryDate: expiryDate,
          batchNumber: batchNumberController.text.trim().isEmpty 
              ? null 
              : batchNumberController.text.trim(),
          lastUpdated: DateTime.now(),
        );

        await _dataService.addInventoryItem(item);
        await _loadInventory();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إضافة الدواء بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ في إضافة الدواء: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showEditMedicationDialog(MedicationInventoryModel item) async {
    final quantityController = TextEditingController(text: item.quantity.toString());
    final priceController = TextEditingController(text: item.price.toStringAsFixed(2));

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تعديل: ${item.medicationName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: quantityController,
              decoration: const InputDecoration(
                labelText: 'الكمية',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(
                labelText: 'السعر',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
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
    );

    if (result == true) {
      try {
        final quantity = int.tryParse(quantityController.text.trim()) ?? item.quantity;
        final price = double.tryParse(priceController.text.trim()) ?? item.price;
        
        await _dataService.updateInventoryItem(
          item.id,
          quantity: quantity,
          price: price,
        );
        
        await _loadInventory();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تحديث الدواء بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ في تحديث الدواء: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteMedication(String medicationId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذا الدواء من المخزون؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _dataService.deleteInventoryItem(medicationId);
        await _loadInventory();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حذف الدواء بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ في حذف الدواء: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
