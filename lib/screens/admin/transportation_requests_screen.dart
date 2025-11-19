import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/transportation_models.dart';
import '../../services/data_service.dart';
import 'create_transportation_request_screen.dart';

class TransportationRequestsScreen extends StatefulWidget {
  const TransportationRequestsScreen({super.key});

  @override
  State<TransportationRequestsScreen> createState() => _TransportationRequestsScreenState();
}

class _TransportationRequestsScreenState extends State<TransportationRequestsScreen> {
  final DataService _dataService = DataService();
  List<TransportationRequestModel> _requests = [];
  bool _isLoading = true;
  TransportationRequestStatus? _filterStatus;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final requests = await _dataService.getTransportationRequests(status: _filterStatus);
      setState(() {
        _requests = requests.cast<TransportationRequestModel>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
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
                : _requests.isEmpty
                    ? const Center(child: Text('لا توجد طلبات نقل'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _requests.length,
                        itemBuilder: (context, index) {
                          return _buildRequestCard(_requests[index]);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateTransportationRequestScreen()),
        ).then((_) => _loadRequests()),
        icon: const Icon(Icons.add),
        label: const Text('طلب نقل جديد'),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: DropdownButtonFormField<TransportationRequestStatus?>(
        value: _filterStatus,
        decoration: const InputDecoration(
          labelText: 'فلترة حسب الحالة',
          border: OutlineInputBorder(),
        ),
        items: [
          const DropdownMenuItem(value: null, child: Text('جميع الحالات')),
          ...TransportationRequestStatus.values.map((status) {
            final statusText = {
              TransportationRequestStatus.pending: 'قيد الانتظار',
              TransportationRequestStatus.assigned: 'مكلفة',
              TransportationRequestStatus.inTransit: 'قيد النقل',
              TransportationRequestStatus.completed: 'مكتملة',
              TransportationRequestStatus.cancelled: 'ملغاة',
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

  Widget _buildRequestCard(TransportationRequestModel request) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm', 'ar');
    
    final typeText = {
      TransportationRequestType.pickup: 'استلام',
      TransportationRequestType.dropoff: 'توصيل',
      TransportationRequestType.transfer: 'نقل',
      TransportationRequestType.emergency: 'طوارئ',
    }[request.type]!;

    final statusColor = {
      TransportationRequestStatus.pending: Colors.orange,
      TransportationRequestStatus.assigned: Colors.blue,
      TransportationRequestStatus.inTransit: Colors.purple,
      TransportationRequestStatus.completed: Colors.green,
      TransportationRequestStatus.cancelled: Colors.grey,
    }[request.status]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.2),
          child: Icon(Icons.transfer_within_a_station, color: statusColor),
        ),
        title: Text('${request.patientName ?? request.patientId} - $typeText'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (request.pickupLocation != null) Text('من: ${request.pickupLocation}'),
            if (request.dropoffLocation != null) Text('إلى: ${request.dropoffLocation}'),
            if (request.ambulanceNumber != null) Text('سيارة: ${request.ambulanceNumber}'),
            Text('تاريخ الطلب: ${dateFormat.format(request.requestedDate)}'),
          ],
        ),
        trailing: Text(_getStatusText(request.status)),
      ),
    );
  }

  String _getStatusText(TransportationRequestStatus status) {
    return {
      TransportationRequestStatus.pending: 'قيد الانتظار',
      TransportationRequestStatus.assigned: 'مكلفة',
      TransportationRequestStatus.inTransit: 'قيد النقل',
      TransportationRequestStatus.completed: 'مكتملة',
      TransportationRequestStatus.cancelled: 'ملغاة',
    }[status]!;
  }
}

