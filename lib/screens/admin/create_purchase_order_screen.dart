import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/medical_inventory_model.dart';
import '../../services/data_service.dart';
import '../../utils/auth_helper.dart';

class CreatePurchaseOrderScreen extends StatefulWidget {
  const CreatePurchaseOrderScreen({super.key});

  @override
  State<CreatePurchaseOrderScreen> createState() => _CreatePurchaseOrderScreenState();
}

class _CreatePurchaseOrderScreenState extends State<CreatePurchaseOrderScreen> {
  final DataService _dataService = DataService();
  final Uuid _uuid = const Uuid();
  final _notesController = TextEditingController();
  SupplierModel? _selectedSupplier;
  List<SupplierModel> _suppliers = [];
  List<MedicalInventoryItemModel> _availableItems = [];
  final List<PurchaseOrderItem> _orderItems = [];
  int _orderNumberCounter = 1;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final suppliers = await _dataService.getSuppliers();
      final items = await _dataService.getMedicalInventory();
      setState(() {
        _suppliers = suppliers.cast<SupplierModel>();
        _availableItems = items.cast<MedicalInventoryItemModel>();
      });
    } catch (e) {
      debugPrint('خطأ في تحميل البيانات: $e');
    }
  }

  double get _totalAmount {
    return _orderItems.fold(0.0, (sum, item) => sum + item.total);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء طلب شراء'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSupplierSection(),
            const SizedBox(height: 24),
            _buildItemsSection(),
            const SizedBox(height: 24),
            _buildSummarySection(),
            const SizedBox(height: 24),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'ملاحظات (اختياري)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _orderItems.isEmpty ? null : _saveOrder,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('حفظ طلب الشراء'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupplierSection() {
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
            const SizedBox(height: 16),
            if (_selectedSupplier == null)
              ElevatedButton.icon(
                onPressed: _selectSupplier,
                icon: const Icon(Icons.business),
                label: const Text('اختر مورد'),
              )
            else
              ListTile(
                leading: const Icon(Icons.business),
                title: Text(_selectedSupplier!.name),
                subtitle: Text(_selectedSupplier!.phone ?? ''),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _selectedSupplier = null),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'عناصر الطلب',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة عنصر'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_orderItems.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('لا توجد عناصر في الطلب'),
                ),
              )
            else
              ..._orderItems.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(item.itemName),
                    subtitle: Text('الكمية: ${item.quantity} × ${item.unitPrice.toStringAsFixed(2)} = ${item.total.toStringAsFixed(2)} ريال'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() => _orderItems.removeAt(index));
                      },
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'المبلغ الإجمالي:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_totalAmount.toStringAsFixed(2)} ريال',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectSupplier() async {
    if (_suppliers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد موردين. يرجى إضافة مورد أولاً')),
      );
      return;
    }

    final selected = await showDialog<SupplierModel>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اختر مورد'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _suppliers.length,
            itemBuilder: (context, index) {
              final supplier = _suppliers[index];
              return ListTile(
                leading: const Icon(Icons.business),
                title: Text(supplier.name),
                subtitle: Text(supplier.phone ?? ''),
                onTap: () => Navigator.pop(context, supplier),
              );
            },
          ),
        ),
      ),
    );

    if (selected != null) {
      setState(() => _selectedSupplier = selected);
    }
  }

  Future<void> _addItem() async {
    if (_availableItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد عناصر متاحة')),
      );
      return;
    }

    MedicalInventoryItemModel? selectedItem;
    final quantityController = TextEditingController();
    final priceController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إضافة عنصر للطلب'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<MedicalInventoryItemModel>(
                  decoration: const InputDecoration(
                    labelText: 'اختر العنصر',
                    border: OutlineInputBorder(),
                  ),
                  items: _availableItems.map((item) {
                    return DropdownMenuItem(
                      value: item,
                      child: Text(item.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedItem = value;
                      if (value?.unitPrice != null) {
                        priceController.text = value!.unitPrice!.toStringAsFixed(2);
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
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
                    labelText: 'سعر الوحدة',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
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
                if (selectedItem == null ||
                    quantityController.text.trim().isEmpty ||
                    priceController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى إدخال جميع البيانات')),
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

    if (result != true || selectedItem == null) return;

    final quantity = int.tryParse(quantityController.text.trim()) ?? 0;
    final unitPrice = double.tryParse(priceController.text.trim()) ?? 0.0;
    final total = quantity * unitPrice;

    setState(() {
      _orderItems.add(PurchaseOrderItem(
        itemId: selectedItem!.id,
        itemName: selectedItem.name,
        quantity: quantity,
        unitPrice: unitPrice,
        total: total,
      ));
    });
  }

  Future<void> _saveOrder() async {
    if (_selectedSupplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار مورد')),
      );
      return;
    }

    try {
      final order = PurchaseOrderModel(
        id: _uuid.v4(),
        orderNumber: 'PO-${DateTime.now().year}-${_orderNumberCounter.toString().padLeft(4, '0')}',
        supplierId: _selectedSupplier!.id,
        supplierName: _selectedSupplier!.name,
        items: _orderItems,
        totalAmount: _totalAmount,
        status: PurchaseOrderStatus.draft,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        requestedBy: AuthHelper.getCurrentUser(context)?.name,
        requestedDate: DateTime.now(),
        createdAt: DateTime.now(),
      );

      await _dataService.createPurchaseOrder(order);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إنشاء طلب الشراء بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إنشاء الطلب: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

