import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/maintenance_models.dart';
import '../../services/data_service.dart';
import 'create_maintenance_request_screen.dart';

class MaintenanceRequestsScreen extends StatefulWidget {
  const MaintenanceRequestsScreen({super.key});

  @override
  State<MaintenanceRequestsScreen> createState() => _MaintenanceRequestsScreenState();
}

class _MaintenanceRequestsScreenState extends State<MaintenanceRequestsScreen> {
  final DataService _dataService = DataService();
  List<MaintenanceRequestModel> _requests = [];
  bool _isLoading = true;
  MaintenanceRequestStatus? _filterStatus;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final requests = await _dataService.getMaintenanceRequests(status: _filterStatus);
      setState(() {
        _requests = requests.cast<MaintenanceRequestModel>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل طلبات الصيانة: $e')),
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
                    onRefresh: _loadRequests,
                    child: _requests.isEmpty
                        ? Center(
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
                                    'لا توجد طلبات صيانة',
                                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _requests.length,
                            itemBuilder: (context, index) {
                              return _buildRequestCard(_requests[index]);
                            },
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateMaintenanceRequestScreen()),
        ).then((_) => _loadRequests()),
        icon: const Icon(Icons.add),
        label: const Text('طلب صيانة جديد'),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: DropdownButtonFormField<MaintenanceRequestStatus?>(
        value: _filterStatus,
        decoration: const InputDecoration(
          labelText: 'فلترة حسب الحالة',
          border: OutlineInputBorder(),
        ),
        items: [
          const DropdownMenuItem(value: null, child: Text('جميع الحالات')),
          ...MaintenanceRequestStatus.values.map((status) {
            final statusText = {
              MaintenanceRequestStatus.pending: 'قيد الانتظار',
              MaintenanceRequestStatus.assigned: 'مكلفة',
              MaintenanceRequestStatus.inProgress: 'قيد التنفيذ',
              MaintenanceRequestStatus.completed: 'مكتملة',
              MaintenanceRequestStatus.cancelled: 'ملغاة',
            }[status]!;
            return DropdownMenuItem(value: status, child: Text(statusText));
          }),
        ],
        onChanged: (value) {
          setState(() => _filterStatus = value);
          _loadRequests();
        },
      ),
    );
  }

  Widget _buildRequestCard(MaintenanceRequestModel request) {
    final dateFormat = DateFormat('yyyy-MM-dd', 'ar');
    
    final typeText = {
      MaintenanceRequestType.corrective: 'تصحيحية',
      MaintenanceRequestType.preventive: 'وقائية',
      MaintenanceRequestType.emergency: 'طارئة',
      MaintenanceRequestType.inspection: 'فحص',
    }[request.type]!;

    final priorityColor = {
      MaintenancePriority.low: Colors.green,
      MaintenancePriority.medium: Colors.blue,
      MaintenancePriority.high: Colors.orange,
      MaintenancePriority.urgent: Colors.red,
    }[request.priority]!;

    final statusColor = {
      MaintenanceRequestStatus.pending: Colors.orange,
      MaintenanceRequestStatus.assigned: Colors.blue,
      MaintenanceRequestStatus.inProgress: Colors.purple,
      MaintenanceRequestStatus.completed: Colors.green,
      MaintenanceRequestStatus.cancelled: Colors.grey,
    }[request.status]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          // TODO: Navigate to request details
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.equipmentName ?? 'معدة غير محددة',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          typeText,
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: priorityColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getPriorityText(request.priority),
                      style: TextStyle(
                        fontSize: 12,
                        color: priorityColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                request.description,
                style: TextStyle(color: Colors.grey[700]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getStatusText(request.status),
                      style: TextStyle(
                        fontSize: 12,
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'تاريخ الإبلاغ: ${dateFormat.format(request.reportedDate)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getPriorityText(MaintenancePriority priority) {
    return {
      MaintenancePriority.low: 'منخفضة',
      MaintenancePriority.medium: 'متوسطة',
      MaintenancePriority.high: 'عالية',
      MaintenancePriority.urgent: 'عاجلة',
    }[priority]!;
  }

  String _getStatusText(MaintenanceRequestStatus status) {
    return {
      MaintenanceRequestStatus.pending: 'قيد الانتظار',
      MaintenanceRequestStatus.assigned: 'مكلفة',
      MaintenanceRequestStatus.inProgress: 'قيد التنفيذ',
      MaintenanceRequestStatus.completed: 'مكتملة',
      MaintenanceRequestStatus.cancelled: 'ملغاة',
    }[status]!;
  }
}

