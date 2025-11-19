import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/surgery_model.dart';
import '../../services/data_service.dart';
import 'create_surgery_screen.dart';
import 'surgery_details_screen.dart';

class SurgeryManagementScreen extends StatefulWidget {
  const SurgeryManagementScreen({super.key});

  @override
  State<SurgeryManagementScreen> createState() => _SurgeryManagementScreenState();
}

class _SurgeryManagementScreenState extends State<SurgeryManagementScreen> {
  final DataService _dataService = DataService();
  List<SurgeryModel> _surgeries = [];
  bool _isLoading = true;
  SurgeryStatus? _filterStatus;
  SurgeryType? _filterType;

  @override
  void initState() {
    super.initState();
    _loadSurgeries();
  }

  Future<void> _loadSurgeries() async {
    setState(() => _isLoading = true);
    try {
      final surgeries = await _dataService.getSurgeries(status: _filterStatus);
      setState(() {
        _surgeries = surgeries.cast<SurgeryModel>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل العمليات: $e')),
        );
      }
    }
  }

  List<SurgeryModel> get _filteredSurgeries {
    var filtered = _surgeries;
    if (_filterType != null) {
      filtered = filtered.where((s) => s.type == _filterType).toList();
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة العمليات الجراحية'),
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              if (value == 'status') {
                _showStatusFilter();
              } else if (value == 'type') {
                _showTypeFilter();
              } else if (value == 'clear') {
                setState(() {
                  _filterStatus = null;
                  _filterType = null;
                });
                _loadSurgeries();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'status',
                child: Text('فلترة حسب الحالة'),
              ),
              const PopupMenuItem(
                value: 'type',
                child: Text('فلترة حسب النوع'),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Text('إزالة الفلاتر'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _createSurgery(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSurgeries,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSurgeries,
              child: _buildSurgeriesList(),
            ),
    );
  }

  Widget _buildSurgeriesList() {
    if (_filteredSurgeries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.medical_services_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'لا توجد عمليات جراحية',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredSurgeries.length,
      itemBuilder: (context, index) {
        final surgery = _filteredSurgeries[index];
        return _buildSurgeryCard(surgery);
      },
    );
  }

  Widget _buildSurgeryCard(SurgeryModel surgery) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm', 'ar');

    final statusColor = {
      SurgeryStatus.scheduled: Colors.blue,
      SurgeryStatus.inProgress: Colors.orange,
      SurgeryStatus.completed: Colors.green,
      SurgeryStatus.cancelled: Colors.red,
      SurgeryStatus.postponed: Colors.grey,
    }[surgery.status]!;

    final statusText = {
      SurgeryStatus.scheduled: 'مجدولة',
      SurgeryStatus.inProgress: 'قيد التنفيذ',
      SurgeryStatus.completed: 'مكتملة',
      SurgeryStatus.cancelled: 'ملغاة',
      SurgeryStatus.postponed: 'مؤجلة',
    }[surgery.status]!;

    final typeText = {
      SurgeryType.elective: 'اختياري',
      SurgeryType.emergency: 'طارئ',
      SurgeryType.urgent: 'عاجل',
    }[surgery.type]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.2),
          child: Icon(Icons.medical_services, color: statusColor),
        ),
        title: Text(
          surgery.surgeryName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('المريض: ${surgery.patientName}'),
            Text('الجراح: ${surgery.surgeonName}'),
            Text('التاريخ: ${dateFormat.format(surgery.scheduledDate)}'),
            if (surgery.operationRoomName != null)
              Text('غرفة العمليات: ${surgery.operationRoomName}'),
            Text('النوع: $typeText'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Chip(
              label: Text(statusText, style: const TextStyle(fontSize: 12)),
              backgroundColor: statusColor.withValues(alpha: 0.2),
              labelStyle: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        onTap: () => _viewSurgeryDetails(surgery),
      ),
    );
  }

  void _createSurgery() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateSurgeryScreen()),
    ).then((_) => _loadSurgeries());
  }

  void _viewSurgeryDetails(SurgeryModel surgery) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SurgeryDetailsScreen(surgery: surgery),
      ),
    ).then((_) => _loadSurgeries());
  }

  void _showStatusFilter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('فلترة حسب الحالة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<SurgeryStatus?>(
              title: const Text('جميع الحالات'),
              value: null,
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() => _filterStatus = value);
                Navigator.pop(context);
                _loadSurgeries();
              },
            ),
            RadioListTile<SurgeryStatus?>(
              title: const Text('مجدولة'),
              value: SurgeryStatus.scheduled,
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() => _filterStatus = value);
                Navigator.pop(context);
                _loadSurgeries();
              },
            ),
            RadioListTile<SurgeryStatus?>(
              title: const Text('قيد التنفيذ'),
              value: SurgeryStatus.inProgress,
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() => _filterStatus = value);
                Navigator.pop(context);
                _loadSurgeries();
              },
            ),
            RadioListTile<SurgeryStatus?>(
              title: const Text('مكتملة'),
              value: SurgeryStatus.completed,
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() => _filterStatus = value);
                Navigator.pop(context);
                _loadSurgeries();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showTypeFilter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('فلترة حسب النوع'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<SurgeryType?>(
              title: const Text('جميع الأنواع'),
              value: null,
              groupValue: _filterType,
              onChanged: (value) {
                setState(() => _filterType = value);
                Navigator.pop(context);
              },
            ),
            RadioListTile<SurgeryType?>(
              title: const Text('اختياري'),
              value: SurgeryType.elective,
              groupValue: _filterType,
              onChanged: (value) {
                setState(() => _filterType = value);
                Navigator.pop(context);
              },
            ),
            RadioListTile<SurgeryType?>(
              title: const Text('طارئ'),
              value: SurgeryType.emergency,
              groupValue: _filterType,
              onChanged: (value) {
                setState(() => _filterType = value);
                Navigator.pop(context);
              },
            ),
            RadioListTile<SurgeryType?>(
              title: const Text('عاجل'),
              value: SurgeryType.urgent,
              groupValue: _filterType,
              onChanged: (value) {
                setState(() => _filterType = value);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

