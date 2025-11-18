import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/data_service.dart';
import '../../models/lab_request_model.dart';
import '../../providers/auth_provider_local.dart';
import '../../widgets/loading_widgets.dart';
import '../../widgets/status_banner.dart';
import '../../utils/ui_snackbar.dart';
import 'package:url_launcher/url_launcher.dart';

class PatientLabRequestsScreen extends StatefulWidget {
  const PatientLabRequestsScreen({super.key});

  @override
  State<PatientLabRequestsScreen> createState() => _PatientLabRequestsScreenState();
}

class _PatientLabRequestsScreenState extends State<PatientLabRequestsScreen> {
  final DataService _dataService = DataService();
  List<LabRequestModel> _requests = [];
  bool _isLoading = true;
  String? _errorMessage;
  LabRequestStatus? _filterStatus;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProviderLocal>(context, listen: false);
      final patientId = authProvider.currentUser?.id ?? '';
      
      if (patientId.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'يرجى تسجيل الدخول أولاً';
        });
        return;
      }

      final list = await _dataService.getLabRequests(patientId: patientId) as List;
      final requests = list.cast<LabRequestModel>();
      
      setState(() {
        _requests = requests;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
      if (mounted) {
        showFriendlyAuthError(context, e);
      }
    }
  }

  List<LabRequestModel> get _filteredRequests {
    if (_filterStatus == null) {
      return _requests;
    }
    return _requests.where((r) => r.status == _filterStatus).toList();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلبات الفحوصات والتحاليل'),
        actions: [
          PopupMenuButton<LabRequestStatus?>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'فلترة حسب الحالة',
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
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_errorMessage != null)
            StatusBanner(
              message: 'خطأ في تحميل الطلبات: $_errorMessage',
              type: StatusBannerType.error,
              onDismiss: () => setState(() => _errorMessage = null),
            ),
          Expanded(
            child: _isLoading
                ? const ListSkeletonLoader(itemCount: 5)
                : _filteredRequests.isEmpty
                    ? EmptyStateWidget(
                        icon: Icons.biotech_outlined,
                        title: _filterStatus == null
                            ? 'لا توجد طلبات فحوصات'
                            : 'لا توجد طلبات بهذه الحالة',
                        subtitle: 'سيتم عرض طلبات الفحوصات التي يطلبها الأطباء هنا',
                      )
                    : RefreshIndicator(
                        onRefresh: _loadRequests,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredRequests.length,
                          itemBuilder: (context, index) {
                            final request = _filteredRequests[index];
                            return _buildRequestCard(request, dateFormat);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(LabRequestModel request, DateFormat dateFormat) {
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.1),
          child: Icon(
            Icons.biotech,
            color: statusColor,
          ),
        ),
        title: Text(
          request.testType,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'بتاريخ: ${dateFormat.format(request.requestedAt)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
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
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    request.notes!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (request.status == LabRequestStatus.completed) ...[
                  if (request.resultNotes != null && request.resultNotes!.isNotEmpty) ...[
                    const Text(
                      'نتائج الفحص:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      request.resultNotes!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (request.attachments != null && request.attachments!.isNotEmpty) ...[
                    const Text(
                      'المرفقات:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: request.attachments!.map((url) {
                        return _buildAttachmentChip(url);
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (request.completedAt != null)
                    Text(
                      'تاريخ الإكمال: ${dateFormat.format(request.completedAt!)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentChip(String url) {
    final isPdf = url.toLowerCase().endsWith('.pdf');
    final isImage = url.toLowerCase().contains('image') ||
        url.toLowerCase().endsWith('.png') ||
        url.toLowerCase().endsWith('.jpg') ||
        url.toLowerCase().endsWith('.jpeg');

    return ActionChip(
      avatar: Icon(
        isPdf ? Icons.picture_as_pdf : isImage ? Icons.image : Icons.attach_file,
        size: 18,
      ),
      label: Text(
        isPdf ? 'PDF' : isImage ? 'صورة' : 'ملف',
        style: const TextStyle(fontSize: 12),
      ),
      onPressed: () => _openAttachment(url),
    );
  }

  Future<void> _openAttachment(String url) async {
    try {
      Uri uri;
      if (url.startsWith('http')) {
        uri = Uri.parse(url);
      } else if (url.startsWith('/')) {
        uri = Uri.parse(url);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('الملفات المحلية غير مدعومة على الويب')),
          );
        }
        return;
      }

      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر فتح الرابط')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في فتح المرفق: $e')),
        );
      }
    }
  }
}

