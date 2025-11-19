import 'package:flutter/material.dart';
import '../../models/transportation_models.dart';
import '../../services/data_service.dart';
import 'create_ambulance_screen.dart';

class AmbulancesManagementScreen extends StatefulWidget {
  const AmbulancesManagementScreen({super.key});

  @override
  State<AmbulancesManagementScreen> createState() => _AmbulancesManagementScreenState();
}

class _AmbulancesManagementScreenState extends State<AmbulancesManagementScreen> {
  final DataService _dataService = DataService();
  List<AmbulanceModel> _ambulances = [];
  bool _isLoading = true;
  AmbulanceStatus? _filterStatus;

  @override
  void initState() {
    super.initState();
    _loadAmbulances();
  }

  Future<void> _loadAmbulances() async {
    setState(() => _isLoading = true);
    try {
      final ambulances = await _dataService.getAmbulances(status: _filterStatus);
      setState(() {
        _ambulances = ambulances.cast<AmbulanceModel>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل سيارات الإسعاف: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadAmbulances,
                    child: _ambulances.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.local_shipping_outlined,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'لا توجد سيارات إسعاف',
                                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _ambulances.length,
                            itemBuilder: (context, index) {
                              return _buildAmbulanceCard(_ambulances[index]);
                            },
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateAmbulanceScreen()),
        ).then((_) => _loadAmbulances()),
        icon: const Icon(Icons.add),
        label: const Text('إضافة سيارة إسعاف'),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: DropdownButtonFormField<AmbulanceStatus?>(
        value: _filterStatus,
        decoration: const InputDecoration(
          labelText: 'فلترة حسب الحالة',
          border: OutlineInputBorder(),
        ),
        items: [
          const DropdownMenuItem(value: null, child: Text('جميع الحالات')),
          ...AmbulanceStatus.values.map((status) {
            final statusText = {
              AmbulanceStatus.available: 'متاحة',
              AmbulanceStatus.onDuty: 'في الخدمة',
              AmbulanceStatus.maintenance: 'صيانة',
              AmbulanceStatus.outOfService: 'خارج الخدمة',
            }[status]!;
            return DropdownMenuItem(value: status, child: Text(statusText));
          }),
        ],
        onChanged: (value) {
          setState(() => _filterStatus = value);
          _loadAmbulances();
        },
      ),
    );
  }

  Widget _buildAmbulanceCard(AmbulanceModel ambulance) {
    final statusColor = {
      AmbulanceStatus.available: Colors.green,
      AmbulanceStatus.onDuty: Colors.blue,
      AmbulanceStatus.maintenance: Colors.orange,
      AmbulanceStatus.outOfService: Colors.grey,
    }[ambulance.status]!;

    final typeText = {
      AmbulanceType.basic: 'أساسي',
      AmbulanceType.advanced: 'متقدم',
      AmbulanceType.critical: 'حرج',
    }[ambulance.type]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.2),
          child: Icon(Icons.local_shipping, color: statusColor),
        ),
        title: Text(ambulance.vehicleNumber),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (ambulance.vehicleModel != null) Text('موديل: ${ambulance.vehicleModel}'),
            Text('نوع: $typeText'),
            if (ambulance.driverName != null) Text('سائق: ${ambulance.driverName}'),
            if (ambulance.location != null) Text('موقع: ${ambulance.location}'),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _getStatusText(ambulance.status),
            style: TextStyle(
              fontSize: 12,
              color: statusColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  String _getStatusText(AmbulanceStatus status) {
    return {
      AmbulanceStatus.available: 'متاحة',
      AmbulanceStatus.onDuty: 'في الخدمة',
      AmbulanceStatus.maintenance: 'صيانة',
      AmbulanceStatus.outOfService: 'خارج الخدمة',
    }[status]!;
  }
}

