import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/lab_request_model.dart';
import '../../providers/auth_provider_local.dart';
import '../../services/data_service.dart';

class LabTechnicianRequestsScreen extends StatefulWidget {
  const LabTechnicianRequestsScreen({super.key});

  @override
  State<LabTechnicianRequestsScreen> createState() => _LabTechnicianRequestsScreenState();
}

class _LabTechnicianRequestsScreenState extends State<LabTechnicianRequestsScreen> {
  final DataService _dataService = DataService();
  List<LabRequestModel> _requests = [];
  bool _isLoading = true;
  LabRequestStatus? _filterStatus;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      // فني المختبر يرى جميع الطلبات (ليس فقط طلبات طبيب معين)
      final requests = await _dataService.getLabRequests();
      setState(() {
        _requests = requests.cast<LabRequestModel>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل طلبات الفحوصات: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلبات الفحوصات'),
        actions: [
          PopupMenuButton<LabRequestStatus?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (status) {
              setState(() => _filterStatus = status);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('جميع الطلبات'),
              ),
              const PopupMenuItem(
                value: LabRequestStatus.pending,
                child: Text('قيد الانتظار'),
              ),
              const PopupMenuItem(
                value: LabRequestStatus.inProgress,
                child: Text('قيد التنفيذ'),
              ),
              const PopupMenuItem(
                value: LabRequestStatus.completed,
                child: Text('مكتملة'),
              ),
              const PopupMenuItem(
                value: LabRequestStatus.cancelled,
                child: Text('ملغاة'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRequests,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadRequests,
              child: _buildRequestsList(),
            ),
    );
  }

  Widget _buildRequestsList() {
    final filteredRequests = _filterStatus == null
        ? _requests
        : _requests.where((r) => r.status == _filterStatus).toList();

    if (filteredRequests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.science_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                _filterStatus == null
                    ? 'لا توجد طلبات فحوصات'
                    : 'لا توجد طلبات بهذه الحالة',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredRequests.length,
      itemBuilder: (context, index) {
        final request = filteredRequests[index];
        return _buildRequestCard(request);
      },
    );
  }

  Widget _buildRequestCard(LabRequestModel request) {
    final statusColor = {
      LabRequestStatus.pending: Colors.orange,
      LabRequestStatus.inProgress: Colors.blue,
      LabRequestStatus.completed: Colors.green,
      LabRequestStatus.cancelled: Colors.red,
    }[request.status]!;

    final statusText = {
      LabRequestStatus.pending: 'قيد الانتظار',
      LabRequestStatus.inProgress: 'قيد التنفيذ',
      LabRequestStatus.completed: 'مكتملة',
      LabRequestStatus.cancelled: 'ملغاة',
    }[request.status]!;

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm', 'ar');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.2),
          child: Icon(Icons.science, color: statusColor),
        ),
        title: Text(
          request.testType,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('المريض: ${request.patientName}'),
            Text('التاريخ: ${dateFormat.format(request.requestedAt)}'),
            Chip(
              label: Text(statusText, style: const TextStyle(fontSize: 12)),
              backgroundColor: statusColor.withValues(alpha: 0.2),
              labelStyle: TextStyle(color: statusColor),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (request.notes != null && request.notes!.isNotEmpty) ...[
                  const Text(
                    'ملاحظات الطبيب:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(request.notes!),
                  const SizedBox(height: 16),
                ],
                if (request.resultNotes != null && request.resultNotes!.isNotEmpty) ...[
                  const Text(
                    'نتائج الفحص:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(request.resultNotes!),
                  const SizedBox(height: 16),
                ],
                if (request.attachments != null && request.attachments!.isNotEmpty) ...[
                  const Text(
                    'المرفقات:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...request.attachments!.map((url) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.attach_file),
                          title: Text(url),
                          trailing: const Icon(Icons.open_in_new),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('فتح: $url')),
                            );
                          },
                        ),
                      )),
                  const SizedBox(height: 16),
                ],
                if (request.status != LabRequestStatus.completed &&
                    request.status != LabRequestStatus.cancelled) ...[
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (request.status == LabRequestStatus.pending)
                        ElevatedButton.icon(
                          onPressed: () => _updateStatus(request, LabRequestStatus.inProgress),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('بدء التنفيذ'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      if (request.status == LabRequestStatus.inProgress)
                        ElevatedButton.icon(
                          onPressed: () => _showAddResultsDialog(request),
                          icon: const Icon(Icons.check),
                          label: const Text('إضافة النتائج'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(LabRequestModel request, LabRequestStatus newStatus) async {
    try {
      await _dataService.updateLabRequest(
        request.id,
        status: newStatus.toString().split('.').last,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث حالة الطلب بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        _loadRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحديث الحالة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showAddResultsDialog(LabRequestModel request) async {
    final resultNotesController = TextEditingController();
    final attachmentsController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة نتائج الفحص'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: resultNotesController,
                decoration: const InputDecoration(
                  labelText: 'نتائج الفحص *',
                  hintText: 'أدخل نتائج الفحص...',
                ),
                maxLines: 5,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: attachmentsController,
                decoration: const InputDecoration(
                  labelText: 'المرفقات (اختياري)',
                  hintText: 'روابط الملفات مفصولة بفاصلة',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (resultNotesController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('يرجى إدخال نتائج الفحص')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (result != true) return;

    try {
      final attachments = attachmentsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      await _dataService.updateLabRequest(
        request.id,
        status: LabRequestStatus.completed.toString().split('.').last,
        resultNotes: resultNotesController.text.trim(),
        resultAttachments: attachments.isNotEmpty ? attachments : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إضافة النتائج بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        _loadRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إضافة النتائج: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

