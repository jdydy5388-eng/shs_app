import 'package:flutter/material.dart';
import '../../models/quality_models.dart';
import '../../services/data_service.dart';

class ComplaintsManagementScreen extends StatefulWidget {
  const ComplaintsManagementScreen({super.key});

  @override
  State<ComplaintsManagementScreen> createState() => _ComplaintsManagementScreenState();
}

class _ComplaintsManagementScreenState extends State<ComplaintsManagementScreen> {
  final DataService _dataService = DataService();
  List<ComplaintModel> _complaints = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadComplaints();
  }

  Future<void> _loadComplaints() async {
    setState(() => _isLoading = true);
    try {
      final complaints = await _dataService.getComplaints();
      setState(() {
        _complaints = complaints.cast<ComplaintModel>();
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
          : _complaints.isEmpty
              ? const Center(child: Text('لا توجد شكاوى'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _complaints.length,
                  itemBuilder: (context, index) {
                    final complaint = _complaints[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(complaint.subject),
                        subtitle: Text(complaint.description),
                        trailing: Text(_getStatusText(complaint.status)),
                      ),
                    );
                  },
                ),
    );
  }

  String _getStatusText(ComplaintStatus status) {
    return {
      ComplaintStatus.newComplaint: 'جديدة',
      ComplaintStatus.inProgress: 'قيد المعالجة',
      ComplaintStatus.resolved: 'تم الحل',
      ComplaintStatus.closed: 'مغلق',
      ComplaintStatus.rejected: 'مرفوضة',
    }[status]!;
  }
}

