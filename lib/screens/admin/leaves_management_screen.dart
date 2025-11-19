import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/hr_models.dart';
import '../../services/data_service.dart';
import 'create_leave_request_screen.dart';

class LeavesManagementScreen extends StatefulWidget {
  const LeavesManagementScreen({super.key});

  @override
  State<LeavesManagementScreen> createState() => _LeavesManagementScreenState();
}

class _LeavesManagementScreenState extends State<LeavesManagementScreen> {
  final DataService _dataService = DataService();
  List<LeaveRequestModel> _leaves = [];
  bool _isLoading = true;
  LeaveStatus? _filterStatus;

  @override
  void initState() {
    super.initState();
    _loadLeaves();
  }

  Future<void> _loadLeaves() async {
    setState(() => _isLoading = true);
    try {
      final leaves = await _dataService.getLeaveRequests(status: _filterStatus);
      setState(() {
        _leaves = leaves.cast<LeaveRequestModel>();
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
                : _leaves.isEmpty
                    ? const Center(child: Text('لا توجد طلبات إجازة'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _leaves.length,
                        itemBuilder: (context, index) {
                          return _buildLeaveCard(_leaves[index]);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateLeaveRequestScreen()),
        ).then((_) => _loadLeaves()),
        icon: const Icon(Icons.add),
        label: const Text('طلب إجازة'),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: DropdownButtonFormField<LeaveStatus?>(
        value: _filterStatus,
        decoration: const InputDecoration(
          labelText: 'فلترة حسب الحالة',
          border: OutlineInputBorder(),
        ),
        items: [
          const DropdownMenuItem(value: null, child: Text('جميع الحالات')),
          ...LeaveStatus.values.map((status) {
            final statusText = {
              LeaveStatus.pending: 'قيد المراجعة',
              LeaveStatus.approved: 'موافق عليها',
              LeaveStatus.rejected: 'مرفوضة',
              LeaveStatus.cancelled: 'ملغاة',
            }[status]!;
            return DropdownMenuItem(value: status, child: Text(statusText));
          }),
        ],
        onChanged: (value) {
          setState(() => _filterStatus = value);
          _loadLeaves();
        },
      ),
    );
  }

  Widget _buildLeaveCard(LeaveRequestModel leave) {
    final dateFormat = DateFormat('yyyy-MM-dd', 'ar');
    
    final typeText = {
      LeaveType.annual: 'سنوية',
      LeaveType.sick: 'مرضية',
      LeaveType.emergency: 'طارئة',
      LeaveType.maternity: 'أمومة',
      LeaveType.paternity: 'أبوة',
      LeaveType.unpaid: 'بدون راتب',
      LeaveType.other: 'أخرى',
    }[leave.type]!;

    final statusColor = {
      LeaveStatus.pending: Colors.orange,
      LeaveStatus.approved: Colors.green,
      LeaveStatus.rejected: Colors.red,
      LeaveStatus.cancelled: Colors.grey,
    }[leave.status]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.2),
          child: Icon(Icons.calendar_today, color: statusColor),
        ),
        title: Text('${leave.employeeName ?? leave.employeeId} - $typeText'),
        subtitle: Text(
          '${dateFormat.format(leave.startDate)} إلى ${dateFormat.format(leave.endDate)} (${leave.days} يوم)',
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _getStatusText(leave.status),
            style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  String _getStatusText(LeaveStatus status) {
    return {
      LeaveStatus.pending: 'قيد المراجعة',
      LeaveStatus.approved: 'موافق عليها',
      LeaveStatus.rejected: 'مرفوضة',
      LeaveStatus.cancelled: 'ملغاة',
    }[status]!;
  }
}

