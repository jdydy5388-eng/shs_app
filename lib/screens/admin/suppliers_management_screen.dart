import 'package:flutter/material.dart';
import '../../models/medical_inventory_model.dart';
import '../../services/data_service.dart';
import 'create_supplier_screen.dart';

class SuppliersManagementScreen extends StatefulWidget {
  const SuppliersManagementScreen({super.key});

  @override
  State<SuppliersManagementScreen> createState() => _SuppliersManagementScreenState();
}

class _SuppliersManagementScreenState extends State<SuppliersManagementScreen> {
  final DataService _dataService = DataService();
  List<SupplierModel> _suppliers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    setState(() => _isLoading = true);
    try {
      final suppliers = await _dataService.getSuppliers();
      setState(() {
        _suppliers = suppliers.cast<SupplierModel>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل الموردين: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الموردين'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _createSupplier(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSuppliers,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSuppliers,
              child: _suppliers.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.business_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'لا توجد موردين مسجلين',
                              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _suppliers.length,
                      itemBuilder: (context, index) {
                        final supplier = _suppliers[index];
                        return _buildSupplierCard(supplier);
                      },
                    ),
            ),
    );
  }

  Widget _buildSupplierCard(SupplierModel supplier) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.business),
        ),
        title: Text(
          supplier.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (supplier.contactPerson != null)
              Text('الشخص المسؤول: ${supplier.contactPerson}'),
            if (supplier.phone != null) Text('الهاتف: ${supplier.phone}'),
            if (supplier.email != null) Text('البريد: ${supplier.email}'),
            if (supplier.address != null) Text('العنوان: ${supplier.address}'),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          // يمكن إضافة شاشة تفاصيل المورد لاحقاً
        },
      ),
    );
  }

  void _createSupplier() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateSupplierScreen()),
    ).then((_) => _loadSuppliers());
  }
}

