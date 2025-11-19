import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../models/invoice_model.dart';
import '../../models/user_model.dart';
import '../../services/data_service.dart';
import '../../utils/auth_helper.dart';

class CreateInvoiceScreen extends StatefulWidget {
  const CreateInvoiceScreen({super.key});

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  final DataService _dataService = DataService();
  final _formKey = GlobalKey<FormState>();
  final Uuid _uuid = const Uuid();

  UserModel? _selectedPatient;
  List<InvoiceItem> _items = [];
  double _discount = 0;
  double _tax = 0;
  String _currency = 'SAR';
  String? _insuranceProvider;
  String? _insurancePolicy;
  String? _relatedType;
  String? _relatedId;

  double get _subtotal => _items.fold(0.0, (sum, item) => sum + item.total);
  double get _total => _subtotal - _discount + _tax;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء فاتورة جديدة'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPatientSelector(),
              const SizedBox(height: 24),
              _buildItemsSection(),
              const SizedBox(height: 24),
              _buildFinancialSection(),
              const SizedBox(height: 24),
              _buildInsuranceSection(),
              const SizedBox(height: 24),
              _buildTotalSection(),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveInvoice,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('حفظ الفاتورة'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPatientSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'اختيار المريض',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_selectedPatient == null)
              ElevatedButton.icon(
                onPressed: _selectPatient,
                icon: const Icon(Icons.person_add),
                label: const Text('اختر مريض'),
              )
            else
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(_selectedPatient!.name),
                subtitle: Text(_selectedPatient!.email ?? ''),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _selectedPatient = null),
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
                  'عناصر الفاتورة',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addItem,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_items.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('لا توجد عناصر. اضغط على + لإضافة عنصر'),
                ),
              )
            else
              ..._items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return _buildItemCard(item, index);
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(InvoiceItem item, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(item.description),
        subtitle: Text('الكمية: ${item.quantity} × ${item.unitPrice.toStringAsFixed(2)} = ${item.total.toStringAsFixed(2)}'),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () {
            setState(() => _items.removeAt(index));
          },
        ),
        onTap: () => _editItem(index),
      ),
    );
  }

  Widget _buildFinancialSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'المعلومات المالية',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'الخصم',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.remove_circle),
              ),
              keyboardType: TextInputType.number,
              initialValue: _discount.toString(),
              onChanged: (value) {
                setState(() => _discount = double.tryParse(value) ?? 0);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'الضريبة',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.receipt),
              ),
              keyboardType: TextInputType.number,
              initialValue: _tax.toString(),
              onChanged: (value) {
                setState(() => _tax = double.tryParse(value) ?? 0);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'العملة',
                border: OutlineInputBorder(),
              ),
              value: _currency,
              items: const [
                DropdownMenuItem(value: 'SAR', child: Text('ريال سعودي (SAR)')),
                DropdownMenuItem(value: 'USD', child: Text('دولار (USD)')),
                DropdownMenuItem(value: 'EUR', child: Text('يورو (EUR)')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _currency = value);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsuranceSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'معلومات التأمين (اختياري)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'شركة التأمين',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.local_hospital),
              ),
              initialValue: _insuranceProvider,
              onChanged: (value) => _insuranceProvider = value.isEmpty ? null : value,
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'رقم البوليصة',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.confirmation_number),
              ),
              initialValue: _insurancePolicy,
              onChanged: (value) => _insurancePolicy = value.isEmpty ? null : value,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalSection() {
    final currencyFormat = NumberFormat.currency(symbol: 'ر.س', decimalDigits: 2);
    
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildTotalRow('المجموع الفرعي', _subtotal),
            const Divider(),
            _buildTotalRow('الخصم', -_discount),
            _buildTotalRow('الضريبة', _tax),
            const Divider(),
            _buildTotalRow(
              'الإجمالي',
              _total,
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, {bool isTotal = false}) {
    final currencyFormat = NumberFormat.currency(symbol: 'ر.س', decimalDigits: 2);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 18 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            currencyFormat.format(amount),
            style: TextStyle(
              fontSize: isTotal ? 20 : 16,
              fontWeight: FontWeight.bold,
              color: isTotal ? Colors.blue : null,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectPatient() async {
    try {
      final patients = await _dataService.getPatients();
      final patientList = patients.cast<UserModel>();

      if (!mounted) return;
      final selected = await showDialog<UserModel>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('اختر مريض'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: patientList.length,
              itemBuilder: (context, index) {
                final patient = patientList[index];
                return ListTile(
                  title: Text(patient.name),
                  subtitle: Text(patient.email ?? ''),
                  onTap: () => Navigator.pop(context, patient),
                );
              },
            ),
          ),
        ),
      );

      if (selected != null) {
        setState(() => _selectedPatient = selected);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل المرضى: $e')),
        );
      }
    }
  }

  void _addItem() {
    _showItemDialog();
  }

  void _editItem(int index) {
    _showItemDialog(item: _items[index], index: index);
  }

  void _showItemDialog({InvoiceItem? item, int? index}) {
    final descriptionController = TextEditingController(text: item?.description ?? '');
    final quantityController = TextEditingController(text: item?.quantity.toString() ?? '1');
    final priceController = TextEditingController(text: item?.unitPrice.toString() ?? '0');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item == null ? 'إضافة عنصر' : 'تعديل عنصر'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'الوصف',
                  border: OutlineInputBorder(),
                ),
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
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              final description = descriptionController.text.trim();
              final quantity = int.tryParse(quantityController.text) ?? 1;
              final price = double.tryParse(priceController.text) ?? 0;

              if (description.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('يرجى إدخال الوصف')),
                );
                return;
              }

              final newItem = InvoiceItem(
                description: description,
                quantity: quantity,
                unitPrice: price,
              );

              setState(() {
                if (index != null) {
                  _items[index] = newItem;
                } else {
                  _items.add(newItem);
                }
              });

              Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveInvoice() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedPatient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار مريض')),
      );
      return;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إضافة عنصر واحد على الأقل')),
      );
      return;
    }

    try {
      final invoice = InvoiceModel(
        id: _uuid.v4(),
        patientId: _selectedPatient!.id,
        patientName: _selectedPatient!.name,
        relatedType: _relatedType,
        relatedId: _relatedId,
        items: _items,
        subtotal: _subtotal,
        discount: _discount,
        tax: _tax,
        total: _total,
        currency: _currency,
        status: InvoiceStatus.draft,
        insuranceProvider: _insuranceProvider,
        insurancePolicy: _insurancePolicy,
        createdAt: DateTime.now(),
      );

      await _dataService.createInvoice(invoice);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إنشاء الفاتورة بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إنشاء الفاتورة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

