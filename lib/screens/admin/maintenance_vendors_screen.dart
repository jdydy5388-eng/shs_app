import 'package:flutter/material.dart';
import '../../models/maintenance_models.dart';
import '../../services/data_service.dart';
import 'create_maintenance_vendor_screen.dart';

class MaintenanceVendorsScreen extends StatefulWidget {
  const MaintenanceVendorsScreen({super.key});

  @override
  State<MaintenanceVendorsScreen> createState() => _MaintenanceVendorsScreenState();
}

class _MaintenanceVendorsScreenState extends State<MaintenanceVendorsScreen> {
  final DataService _dataService = DataService();
  List<MaintenanceVendorModel> _vendors = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVendors();
  }

  Future<void> _loadVendors() async {
    setState(() => _isLoading = true);
    try {
      final vendors = await _dataService.getMaintenanceVendors();
      setState(() {
        _vendors = vendors.cast<MaintenanceVendorModel>();
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
          : _vendors.isEmpty
              ? const Center(child: Text('لا يوجد موردين صيانة'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _vendors.length,
                  itemBuilder: (context, index) {
                    return _buildVendorCard(_vendors[index]);
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateMaintenanceVendorScreen()),
        ).then((_) => _loadVendors()),
        icon: const Icon(Icons.add),
        label: const Text('إضافة مورد'),
      ),
    );
  }

  Widget _buildVendorCard(MaintenanceVendorModel vendor) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: vendor.type == MaintenanceVendorType.internal
              ? Colors.blue
              : Colors.green,
          child: Icon(
            vendor.type == MaintenanceVendorType.internal
                ? Icons.business
                : Icons.business_center,
            color: Colors.white,
          ),
        ),
        title: Text(vendor.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (vendor.contactPerson != null) Text('مسؤول: ${vendor.contactPerson}'),
            if (vendor.phone != null) Text('هاتف: ${vendor.phone}'),
            if (vendor.specialization != null) Text('تخصص: ${vendor.specialization}'),
          ],
        ),
        trailing: vendor.isActive
            ? const Icon(Icons.check_circle, color: Colors.green)
            : const Icon(Icons.cancel, color: Colors.grey),
      ),
    );
  }
}

