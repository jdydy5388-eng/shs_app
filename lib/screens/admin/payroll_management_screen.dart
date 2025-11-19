import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/hr_models.dart';
import '../../services/data_service.dart';
import 'create_payroll_screen.dart';

class PayrollManagementScreen extends StatefulWidget {
  const PayrollManagementScreen({super.key});

  @override
  State<PayrollManagementScreen> createState() => _PayrollManagementScreenState();
}

class _PayrollManagementScreenState extends State<PayrollManagementScreen> {
  final DataService _dataService = DataService();
  List<PayrollModel> _payrolls = [];
  bool _isLoading = true;
  PayrollStatus? _filterStatus;

  @override
  void initState() {
    super.initState();
    _loadPayrolls();
  }

  Future<void> _loadPayrolls() async {
    setState(() => _isLoading = true);
    try {
      final payrolls = await _dataService.getPayrolls(status: _filterStatus);
      setState(() {
        _payrolls = payrolls.cast<PayrollModel>();
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
                : _payrolls.isEmpty
                    ? const Center(child: Text('لا توجد رواتب'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _payrolls.length,
                        itemBuilder: (context, index) {
                          return _buildPayrollCard(_payrolls[index]);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreatePayrollScreen()),
        ).then((_) => _loadPayrolls()),
        icon: const Icon(Icons.add),
        label: const Text('إضافة راتب'),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: DropdownButtonFormField<PayrollStatus?>(
        value: _filterStatus,
        decoration: const InputDecoration(
          labelText: 'فلترة حسب الحالة',
          border: OutlineInputBorder(),
        ),
        items: [
          const DropdownMenuItem(value: null, child: Text('جميع الحالات')),
          ...PayrollStatus.values.map((status) {
            final statusText = {
              PayrollStatus.draft: 'مسودة',
              PayrollStatus.processed: 'معالجة',
              PayrollStatus.paid: 'مدفوعة',
              PayrollStatus.cancelled: 'ملغاة',
            }[status]!;
            return DropdownMenuItem(value: status, child: Text(statusText));
          }),
        ],
        onChanged: (value) {
          setState(() => _filterStatus = value);
          _loadPayrolls();
        },
      ),
    );
  }

  Widget _buildPayrollCard(PayrollModel payroll) {
    final dateFormat = DateFormat('yyyy-MM-dd', 'ar');
    
    final statusColor = {
      PayrollStatus.draft: Colors.grey,
      PayrollStatus.processed: Colors.blue,
      PayrollStatus.paid: Colors.green,
      PayrollStatus.cancelled: Colors.red,
    }[payroll.status]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.2),
          child: Icon(Icons.payment, color: statusColor),
        ),
        title: Text(payroll.employeeName ?? payroll.employeeId),
        subtitle: Text(
          '${dateFormat.format(payroll.payPeriodStart)} - ${dateFormat.format(payroll.payPeriodEnd)}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${payroll.netSalary.toStringAsFixed(2)} ريال',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getStatusText(payroll.status),
                style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusText(PayrollStatus status) {
    return {
      PayrollStatus.draft: 'مسودة',
      PayrollStatus.processed: 'معالجة',
      PayrollStatus.paid: 'مدفوعة',
      PayrollStatus.cancelled: 'ملغاة',
    }[status]!;
  }
}

