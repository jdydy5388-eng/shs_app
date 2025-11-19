import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/hr_models.dart';
import '../../models/user_model.dart';
import '../../services/data_service.dart';
import 'create_employee_screen.dart';
import 'employee_details_screen.dart';

class EmployeesManagementScreen extends StatefulWidget {
  const EmployeesManagementScreen({super.key});

  @override
  State<EmployeesManagementScreen> createState() => _EmployeesManagementScreenState();
}

class _EmployeesManagementScreenState extends State<EmployeesManagementScreen> {
  final DataService _dataService = DataService();
  List<EmployeeModel> _employees = [];
  bool _isLoading = true;
  String _searchQuery = '';
  EmploymentStatus? _filterStatus;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() => _isLoading = true);
    try {
      final employees = await _dataService.getEmployees(status: _filterStatus);
      setState(() {
        _employees = employees.cast<EmployeeModel>();
        if (_searchQuery.isNotEmpty) {
          _employees = _employees.where((e) {
            // TODO: Filter by search query when we have user names
            return true;
          }).toList();
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل الموظفين: $e')),
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
                    onRefresh: _loadEmployees,
                    child: _employees.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.people_outline,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'لا يوجد موظفين',
                                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _employees.length,
                            itemBuilder: (context, index) {
                              return _buildEmployeeCard(_employees[index]);
                            },
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateEmployeeScreen()),
        ).then((_) => _loadEmployees()),
        icon: const Icon(Icons.person_add),
        label: const Text('إضافة موظف'),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'بحث في الموظفين...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
                _loadEmployees();
              },
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<EmploymentStatus?>(
            value: _filterStatus,
            items: [
              const DropdownMenuItem(value: null, child: Text('جميع الحالات')),
              ...EmploymentStatus.values.map((status) {
                final statusText = {
                  EmploymentStatus.active: 'نشط',
                  EmploymentStatus.onLeave: 'في إجازة',
                  EmploymentStatus.suspended: 'موقوف',
                  EmploymentStatus.terminated: 'منتهي الخدمة',
                }[status]!;
                return DropdownMenuItem(value: status, child: Text(statusText));
              }),
            ],
            onChanged: (value) {
              setState(() => _filterStatus = value);
              _loadEmployees();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeCard(EmployeeModel employee) {
    final dateFormat = DateFormat('yyyy-MM-dd', 'ar');
    
    final statusText = {
      EmploymentStatus.active: 'نشط',
      EmploymentStatus.onLeave: 'في إجازة',
      EmploymentStatus.suspended: 'موقوف',
      EmploymentStatus.terminated: 'منتهي الخدمة',
    }[employee.status]!;

    final statusColor = {
      EmploymentStatus.active: Colors.green,
      EmploymentStatus.onLeave: Colors.orange,
      EmploymentStatus.suspended: Colors.red,
      EmploymentStatus.terminated: Colors.grey,
    }[employee.status]!;

    final typeText = {
      EmploymentType.fullTime: 'دوام كامل',
      EmploymentType.partTime: 'دوام جزئي',
      EmploymentType.contract: 'عقد',
      EmploymentType.temporary: 'مؤقت',
    }[employee.employmentType]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EmployeeDetailsScreen(employeeId: employee.id),
          ),
        ).then((_) => _loadEmployees()),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: statusColor.withValues(alpha: 0.2),
                child: Icon(
                  Icons.person,
                  color: statusColor,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee.employeeNumber,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${employee.department} - ${employee.position}',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      typeText,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'تاريخ التعيين: ${dateFormat.format(employee.hireDate)}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 12,
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

