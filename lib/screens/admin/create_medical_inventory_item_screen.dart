import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../models/medical_inventory_model.dart';
import '../../services/data_service.dart';

class CreateMedicalInventoryItemScreen extends StatefulWidget {
  const CreateMedicalInventoryItemScreen({super.key});

  @override
  State<CreateMedicalInventoryItemScreen> createState() => _CreateMedicalInventoryItemScreenState();
}

class _CreateMedicalInventoryItemScreenState extends State<CreateMedicalInventoryItemScreen> {
  final DataService _dataService = DataService();
  final _formKey = GlobalKey<FormState>();
  final Uuid _uuid = const Uuid();

  final _nameController = TextEditingController();
  InventoryItemType _selectedType = InventoryItemType.supplies;
  final _categoryController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _quantityController = TextEditingController(text: '0');
  final _minStockController = TextEditingController();
  final _unitController = TextEditingController();
  final _priceController = TextEditingController();
  final _manufacturerController = TextEditingController();
  final _modelController = TextEditingController();
  final _serialController = TextEditingController();
  final _locationController = TextEditingController();
  DateTime? _purchaseDate;
  DateTime? _expiryDate;
  DateTime? _nextMaintenanceDate;
  EquipmentStatus? _status;
  SupplierModel? _selectedSupplier;
  List<SupplierModel> _suppliers = [];

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    _minStockController.dispose();
    _unitController.dispose();
    _priceController.dispose();
    _manufacturerController.dispose();
    _modelController.dispose();
    _serialController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _loadSuppliers() async {
    try {
      final suppliers = await _dataService.getSuppliers();
      setState(() {
        _suppliers = suppliers.cast<SupplierModel>();
      });
    } catch (e) {
      debugPrint('خطأ في تحميل الموردين: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة عنصر للمستودع'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBasicInfoSection(),
              const SizedBox(height: 24),
              _buildQuantitySection(),
              const SizedBox(height: 24),
              if (_selectedType == InventoryItemType.equipment) ...[
                _buildEquipmentSection(),
                const SizedBox(height: 24),
              ],
              _buildSupplierSection(),
              const SizedBox(height: 24),
              _buildDatesSection(),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveItem,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('حفظ العنصر'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'المعلومات الأساسية',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'اسم العنصر',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.inventory_2),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'يرجى إدخال اسم العنصر';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            const Text('النوع'),
            RadioListTile<InventoryItemType>(
              title: const Text('معدات'),
              value: InventoryItemType.equipment,
              groupValue: _selectedType,
              onChanged: (value) => setState(() => _selectedType = value!),
            ),
            RadioListTile<InventoryItemType>(
              title: const Text('مستلزمات'),
              value: InventoryItemType.supplies,
              groupValue: _selectedType,
              onChanged: (value) => setState(() => _selectedType = value!),
            ),
            RadioListTile<InventoryItemType>(
              title: const Text('مواد استهلاكية'),
              value: InventoryItemType.consumables,
              groupValue: _selectedType,
              onChanged: (value) => setState(() => _selectedType = value!),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _categoryController,
              decoration: const InputDecoration(
                labelText: 'الفئة (اختياري)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'الوصف (اختياري)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantitySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'الكمية والمخزون',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _quantityController,
                    decoration: const InputDecoration(
                      labelText: 'الكمية',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'يرجى إدخال الكمية';
                      }
                      if (int.tryParse(value) == null) {
                        return 'يرجى إدخال رقم صحيح';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _unitController,
                    decoration: const InputDecoration(
                      labelText: 'الوحدة',
                      border: OutlineInputBorder(),
                      hintText: 'قطعة، علبة، لتر',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _minStockController,
              decoration: const InputDecoration(
                labelText: 'الحد الأدنى للمخزون (اختياري)',
                border: OutlineInputBorder(),
                hintText: 'سيتم التنبيه عند الوصول لهذا الحد',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: 'سعر الوحدة (اختياري)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'موقع التخزين (اختياري)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEquipmentSection() {
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
            TextField(
              controller: _manufacturerController,
              decoration: const InputDecoration(
                labelText: 'الشركة المصنعة',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _modelController,
              decoration: const InputDecoration(
                labelText: 'الموديل',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _serialController,
              decoration: const InputDecoration(
                labelText: 'الرقم التسلسلي',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text('الحالة'),
            RadioListTile<EquipmentStatus?>(
              title: const Text('متاحة'),
              value: EquipmentStatus.available,
              groupValue: _status,
              onChanged: (value) => setState(() => _status = value),
            ),
            RadioListTile<EquipmentStatus?>(
              title: const Text('قيد الاستخدام'),
              value: EquipmentStatus.inUse,
              groupValue: _status,
              onChanged: (value) => setState(() => _status = value),
            ),
            RadioListTile<EquipmentStatus?>(
              title: const Text('صيانة'),
              value: EquipmentStatus.maintenance,
              groupValue: _status,
              onChanged: (value) => setState(() => _status = value),
            ),
            RadioListTile<EquipmentStatus?>(
              title: const Text('معطلة'),
              value: EquipmentStatus.outOfOrder,
              groupValue: _status,
              onChanged: (value) => setState(() => _status = value),
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

  Widget _buildDatesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'التواريخ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('تاريخ الشراء'),
              subtitle: Text(_purchaseDate != null
                  ? DateFormat('yyyy-MM-dd', 'ar').format(_purchaseDate!)
                  : 'غير محدد'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _purchaseDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() => _purchaseDate = date);
                }
              },
            ),
            ListTile(
              title: const Text('تاريخ انتهاء الصلاحية'),
              subtitle: Text(_expiryDate != null
                  ? DateFormat('yyyy-MM-dd', 'ar').format(_expiryDate!)
                  : 'غير محدد'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _expiryDate ?? DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                );
                if (date != null) {
                  setState(() => _expiryDate = date);
                }
              },
            ),
            if (_selectedType == InventoryItemType.equipment)
              ListTile(
                title: const Text('تاريخ الصيانة القادمة'),
                subtitle: Text(_nextMaintenanceDate != null
                    ? DateFormat('yyyy-MM-dd', 'ar').format(_nextMaintenanceDate!)
                    : 'غير محدد'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _nextMaintenanceDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() => _nextMaintenanceDate = date);
                  }
                },
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

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final item = MedicalInventoryItemModel(
        id: _uuid.v4(),
        name: _nameController.text.trim(),
        type: _selectedType,
        category: _categoryController.text.trim().isEmpty
            ? null
            : _categoryController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        quantity: int.parse(_quantityController.text.trim()),
        minStockLevel: _minStockController.text.trim().isEmpty
            ? null
            : int.tryParse(_minStockController.text.trim()),
        unit: _unitController.text.trim().isEmpty
            ? null
            : _unitController.text.trim(),
        unitPrice: _priceController.text.trim().isEmpty
            ? null
            : double.tryParse(_priceController.text.trim()),
        manufacturer: _manufacturerController.text.trim().isEmpty
            ? null
            : _manufacturerController.text.trim(),
        model: _modelController.text.trim().isEmpty
            ? null
            : _modelController.text.trim(),
        serialNumber: _serialController.text.trim().isEmpty
            ? null
            : _serialController.text.trim(),
        purchaseDate: _purchaseDate,
        expiryDate: _expiryDate,
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        status: _status,
        nextMaintenanceDate: _nextMaintenanceDate,
        supplierId: _selectedSupplier?.id,
        supplierName: _selectedSupplier?.name,
        createdAt: DateTime.now(),
      );

      await _dataService.createMedicalInventoryItem(item);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إضافة العنصر بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إضافة العنصر: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

