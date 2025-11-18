import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/doctor_task_model.dart';
import '../../models/lab_request_model.dart';
import '../../models/user_model.dart';
import '../../services/data_service.dart';
import '../../utils/auth_helper.dart';

class LabRequestsScreen extends StatefulWidget {
  const LabRequestsScreen({super.key});

  @override
  State<LabRequestsScreen> createState() => _LabRequestsScreenState();
}

class _LabRequestsScreenState extends State<LabRequestsScreen> {
  final DataService _dataService = DataService();
  List<LabRequestModel> _requests = [];
  bool _isLoading = false;
  String? _doctorId;
  LabRequestStatus? _filterStatus;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    final user = AuthHelper.getCurrentUser(context);
    if (user == null) return;
    _doctorId = user.id;
    setState(() => _isLoading = true);
    try {
      final requests = await _dataService.getLabRequests(doctorId: user.id);
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
        title: const Text('طلب الفحوصات والتحاليل'),
        actions: [
          PopupMenuButton<LabRequestStatus?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (status) {
              setState(() => _filterStatus = status);
              _loadRequests();
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
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadRequests,
              child: _buildRequestsList(),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddLabRequestDialog(),
        child: const Icon(Icons.add),
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
                Icons.biotech_outlined,
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.2),
          child: Icon(Icons.biotech, color: statusColor),
        ),
        title: Text(
          request.testType,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('المريض: ${request.patientName}'),
            Text('التاريخ: ${_formatDateTime(request.requestedAt)}'),
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
                if (request.notes != null) ...[
                  const Text(
                    'ملاحظات الطلب:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(request.notes!),
                  const SizedBox(height: 16),
                ],
                if (request.resultNotes != null) ...[
                  const Text(
                    'نتائج الفحص:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                    ),
                    child: Text(request.resultNotes!),
                  ),
                  const SizedBox(height: 16),
                ],
                if (request.attachments != null && request.attachments!.isNotEmpty) ...[
                  const Text(
                    'المرفقات:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...request.attachments!.map((attachment) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.attach_file, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                attachment,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.open_in_new, size: 16),
                              onPressed: () {
                                // TODO: فتح الملف
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('فتح: $attachment')),
                                );
                              },
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 16),
                ],
                if (request.completedAt != null) ...[
                  Text(
                    'تاريخ الإكمال: ${_formatDateTime(request.completedAt!)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (request.status != LabRequestStatus.completed &&
                        request.status != LabRequestStatus.cancelled) ...[
                      TextButton.icon(
                        icon: const Icon(Icons.edit),
                        label: const Text('تحديث النتائج'),
                        onPressed: () => _showUpdateResultsDialog(request),
                      ),
                      const SizedBox(width: 8),
                      if (request.status == LabRequestStatus.pending ||
                          request.status == LabRequestStatus.inProgress)
                        TextButton.icon(
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          label: const Text('إلغاء', style: TextStyle(color: Colors.red)),
                          onPressed: () => _cancelRequest(request.id),
                        ),
                    ],
                    if (request.status == LabRequestStatus.completed)
                      IconButton(
                        icon: const Icon(Icons.check_circle, color: Colors.green),
                        tooltip: 'تم إكمال الطلب',
                        onPressed: null,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddLabRequestDialog() async {
    final patientNameController = TextEditingController();
    final testTypeController = TextEditingController();
    final notesController = TextEditingController();
    String? selectedPatientId;
    List<UserModel> patients = [];

    try {
      patients = (await _dataService.getPatients()).cast<UserModel>();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل المرضى: $e')),
        );
      }
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // العنوان
                Row(
                  children: [
                    const Icon(Icons.add_circle_outline, color: Colors.blue, size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'طلب فحص جديد',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context, false),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // المحتوى
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (patients.isNotEmpty) ...[
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'اختر المريض *',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.person),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            value: selectedPatientId,
                            selectedItemBuilder: (context) {
                              return patients.map((patient) {
                                return Text(
                                  patient.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 16),
                                );
                              }).toList();
                            },
                            items: patients.map((patient) {
                              return DropdownMenuItem(
                                value: patient.id,
                                child: Text(
                                  '${patient.name} - ${patient.email}',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedPatientId = value;
                                if (value != null) {
                                  final patient = patients.firstWhere((p) => p.id == value);
                                  patientNameController.text = patient.name;
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextField(
                          controller: patientNameController,
                          decoration: InputDecoration(
                            labelText: 'اسم المريض *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.badge),
                            filled: true,
                            fillColor: Colors.grey[100],
                          ),
                          enabled: false,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: testTypeController,
                          decoration: InputDecoration(
                            labelText: 'نوع الفحص *',
                            hintText: 'مثل: فحص دم شامل، أشعة سينية، تحليل البول...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.medical_services),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: notesController,
                          decoration: InputDecoration(
                            labelText: 'ملاحظات (اختياري)',
                            hintText: 'أي معلومات إضافية حول الفحص المطلوب',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.note),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // الأزرار
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: const Text('إلغاء', style: TextStyle(fontSize: 16)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        if (selectedPatientId == null || selectedPatientId!.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('يرجى اختيار مريض')),
                          );
                          return;
                        }
                        if (patientNameController.text.trim().isEmpty ||
                            testTypeController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('يرجى ملء جميع الحقول المطلوبة')),
                          );
                          return;
                        }
                        Navigator.pop(context, true);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('إرسال الطلب', style: TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result == true && _doctorId != null) {
      try {
        final request = LabRequestModel(
          id: const Uuid().v4(),
          doctorId: _doctorId!,
          patientId: selectedPatientId ?? '',
          patientName: patientNameController.text.trim(),
          testType: testTypeController.text.trim(),
          status: LabRequestStatus.pending,
          notes: notesController.text.trim().isEmpty
              ? null
              : notesController.text.trim(),
          requestedAt: DateTime.now(),
        );

        await _dataService.createLabRequest(request);
        await _loadRequests();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إرسال طلب الفحص بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ في إرسال الطلب: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showUpdateResultsDialog(LabRequestModel request) async {
    final resultNotesController = TextEditingController(
      text: request.resultNotes ?? '',
    );
    final attachmentsController = TextEditingController(
      text: request.attachments?.join(', ') ?? '',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تحديث نتائج الفحص'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'الفحص: ${request.testType}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('المريض: ${request.patientName}'),
              const SizedBox(height: 16),
              TextField(
                controller: resultNotesController,
                decoration: const InputDecoration(
                  labelText: 'نتائج الفحص *',
                  hintText: 'أدخل نتائج الفحص هنا...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: attachmentsController,
                decoration: const InputDecoration(
                  labelText: 'المرفقات (اختياري)',
                  hintText: 'أسماء الملفات مفصولة بفواصل',
                  border: OutlineInputBorder(),
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
            child: const Text('حفظ النتائج'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final attachments = attachmentsController.text
            .trim()
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

        await _dataService.updateLabRequest(
          request.id,
          status: LabRequestStatus.completed,
          resultNotes: resultNotesController.text.trim(),
          resultAttachments: attachments.isEmpty ? null : attachments,
        );

        // إنشاء مهمة تلقائية للمتابعة
        if (_doctorId != null) {
          final task = DoctorTask(
            id: _dataService.generateId(),
            doctorId: _doctorId!,
            title: 'مراجعة نتائج فحص: ${request.testType}',
            description: 'المريض: ${request.patientName}\nالنتائج: ${resultNotesController.text.trim()}',
            dueDate: DateTime.now().add(const Duration(days: 1)),
            isCompleted: false,
            createdAt: DateTime.now(),
          );
          await _dataService.createTask(task);
        }

        await _loadRequests();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حفظ النتائج بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ في حفظ النتائج: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _cancelRequest(String requestId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الإلغاء'),
        content: const Text('هل أنت متأكد من إلغاء هذا الطلب؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('تأكيد الإلغاء'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _dataService.updateLabRequest(
          requestId,
          status: LabRequestStatus.cancelled,
        );
        await _loadRequests();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إلغاء الطلب')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ في إلغاء الطلب: $e')),
          );
        }
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

