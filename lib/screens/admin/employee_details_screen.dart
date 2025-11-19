import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/hr_models.dart';
import '../../services/data_service.dart';

class EmployeeDetailsScreen extends StatefulWidget {
  final String employeeId;

  const EmployeeDetailsScreen({super.key, required this.employeeId});

  @override
  State<EmployeeDetailsScreen> createState() => _EmployeeDetailsScreenState();
}

class _EmployeeDetailsScreenState extends State<EmployeeDetailsScreen> {
  final DataService _dataService = DataService();
  EmployeeModel? _employee;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEmployee();
  }

  Future<void> _loadEmployee() async {
    setState(() => _isLoading = true);
    try {
      final employee = await _dataService.getEmployee(widget.employeeId);
      if (employee != null && employee is EmployeeModel) {
        setState(() {
          _employee = employee;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('الموظف غير موجود')),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل الموظف: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_employee == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الموظف')),
        body: const Center(child: Text('الموظف غير موجود')),
      );
    }

    final dateFormat = DateFormat('yyyy-MM-dd', 'ar');

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الموظف'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.blue.shade100,
                      child: const Icon(Icons.person, size: 40),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _employee!.employeeNumber,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_employee!.department} - ${_employee!.position}',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'معلومات الموظف',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow('نوع التوظيف', _getTypeText(_employee!.employmentType)),
                    _buildInfoRow('الحالة', _getStatusText(_employee!.status)),
                    _buildInfoRow('تاريخ التعيين', dateFormat.format(_employee!.hireDate)),
                    if (_employee!.terminationDate != null)
                      _buildInfoRow('تاريخ إنهاء الخدمة', dateFormat.format(_employee!.terminationDate!)),
                    if (_employee!.salary != null)
                      _buildInfoRow('الراتب', '${_employee!.salary!.toStringAsFixed(2)} ريال'),
                    if (_employee!.managerName != null)
                      _buildInfoRow('المدير المباشر', _employee!.managerName!),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _getTypeText(EmploymentType type) {
    return {
      EmploymentType.fullTime: 'دوام كامل',
      EmploymentType.partTime: 'دوام جزئي',
      EmploymentType.contract: 'عقد',
      EmploymentType.temporary: 'مؤقت',
    }[type]!;
  }

  String _getStatusText(EmploymentStatus status) {
    return {
      EmploymentStatus.active: 'نشط',
      EmploymentStatus.onLeave: 'في إجازة',
      EmploymentStatus.suspended: 'موقوف',
      EmploymentStatus.terminated: 'منتهي الخدمة',
    }[status]!;
  }
}

