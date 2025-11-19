import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/radiology_model.dart';
import '../../services/data_service.dart';

class RadiologistRequestsScreen extends StatefulWidget {
  const RadiologistRequestsScreen({super.key});

  @override
  State<RadiologistRequestsScreen> createState() => _RadiologistRequestsScreenState();
}

class _RadiologistRequestsScreenState extends State<RadiologistRequestsScreen> {
  final DataService _dataService = DataService();
  List<RadiologyRequestModel> _requests = [];
  final Map<String, List<RadiologyReportModel>> _reports = {};
  bool _isLoading = true;
  String? _filterStatus;
  String? _filterModality;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      // أخصائي الأشعة يرى جميع الطلبات
      final list = await _dataService.getRadiologyRequests();
      final reqs = list.cast<RadiologyRequestModel>();
      final repMap = <String, List<RadiologyReportModel>>{};
      
      for (final r in reqs) {
        final reps = await _dataService.getRadiologyReports(requestId: r.id) as List;
        repMap[r.id] = reps.cast<RadiologyReportModel>();
      }
      
      setState(() {
        _requests = reqs;
        _reports.clear();
        _reports.addAll(repMap);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل طلبات الأشعة: $e')),
        );
      }
    }
  }

  List<RadiologyRequestModel> get _filteredRequests {
    var filtered = _requests;
    
    if (_filterStatus != null) {
      filtered = filtered.where((r) {
        return r.status.toString().split('.').last == _filterStatus;
      }).toList();
    }
    
    if (_filterModality != null) {
      filtered = filtered.where((r) => r.modality == _filterModality).toList();
    }
    
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm', 'ar');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلبات الأشعة'),
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              if (value == 'status') {
                _showStatusFilter();
              } else if (value == 'modality') {
                _showModalityFilter();
              } else if (value == 'clear') {
                setState(() {
                  _filterStatus = null;
                  _filterModality = null;
                });
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'status',
                child: Text('فلترة حسب الحالة'),
              ),
              const PopupMenuItem(
                value: 'modality',
                child: Text('فلترة حسب النوع'),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Text('إزالة الفلاتر'),
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
              child: _buildRequestsList(dateFormat),
            ),
    );
  }

  Widget _buildRequestsList(DateFormat dateFormat) {
    final filtered = _filteredRequests;

    if (filtered.isEmpty) {
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
                'لا توجد طلبات أشعة',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final request = filtered[index];
        return _buildRequestCard(request, dateFormat);
      },
    );
  }

  Widget _buildRequestCard(RadiologyRequestModel request, DateFormat dateFormat) {
    final statusColor = {
      RadiologyStatus.requested: Colors.orange,
      RadiologyStatus.scheduled: Colors.blue,
      RadiologyStatus.completed: Colors.green,
      RadiologyStatus.cancelled: Colors.red,
    }[request.status]!;

    final statusText = {
      RadiologyStatus.requested: 'مطلوبة',
      RadiologyStatus.scheduled: 'مجدولة',
      RadiologyStatus.completed: 'مكتملة',
      RadiologyStatus.cancelled: 'ملغاة',
    }[request.status]!;

    final modalityText = {
      'xray': 'أشعة سينية',
      'ct': 'أشعة مقطعية',
      'mri': 'رنين مغناطيسي',
      'us': 'موجات فوق صوتية',
      'other': 'أخرى',
    }[request.modality] ?? request.modality;

    final reps = _reports[request.id] ?? <RadiologyReportModel>[];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.2),
          child: Icon(Icons.medical_services, color: statusColor),
        ),
        title: Text(
          '$modalityText - ${request.bodyPart ?? 'غير محدد'}',
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
                if (request.scheduledAt != null) ...[
                  const Text(
                    'مجدولة في:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(dateFormat.format(request.scheduledAt!)),
                  const SizedBox(height: 16),
                ],
                const Text(
                  'التقارير:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (reps.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('لا توجد تقارير بعد'),
                    ),
                  )
                else
                  ...reps.map((rep) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (rep.findings != null && rep.findings!.isNotEmpty) ...[
                                const Text(
                                  'Findings:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(rep.findings!),
                                const SizedBox(height: 8),
                              ],
                              if (rep.impression != null && rep.impression!.isNotEmpty) ...[
                                const Text(
                                  'Impression:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(rep.impression!),
                                const SizedBox(height: 8),
                              ],
                              if (rep.attachments != null && rep.attachments!.isNotEmpty) ...[
                                const Text(
                                  'المرفقات:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                ...rep.attachments!.map((url) => ListTile(
                                      leading: const Icon(Icons.attach_file),
                                      title: Text(url),
                                      trailing: const Icon(Icons.open_in_new),
                                      onTap: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('فتح: $url')),
                                        );
                                      },
                                    )),
                              ],
                            ],
                          ),
                        ),
                      )),
                const SizedBox(height: 16),
                if (request.status != RadiologyStatus.completed &&
                    request.status != RadiologyStatus.cancelled) ...[
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (request.status == RadiologyStatus.requested)
                        ElevatedButton.icon(
                          onPressed: () => _scheduleRequest(request),
                          icon: const Icon(Icons.schedule),
                          label: const Text('جدولة'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ElevatedButton.icon(
                        onPressed: () => _showAddReportDialog(request),
                        icon: const Icon(Icons.add),
                        label: const Text('إضافة تقرير'),
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

  Future<void> _scheduleRequest(RadiologyRequestModel request) async {
    final now = DateTime.now().add(const Duration(hours: 1));
    try {
      await _dataService.updateRadiologyRequest(request.id, scheduledAt: now);
      await _dataService.updateRadiologyStatus(
        request.id,
        RadiologyStatus.scheduled,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم جدولة الطلب بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        _loadRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في جدولة الطلب: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showAddReportDialog(RadiologyRequestModel request) async {
    final findingsController = TextEditingController();
    final impressionController = TextEditingController();
    final attachmentsController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة تقرير أشعة'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: findingsController,
                decoration: const InputDecoration(
                  labelText: 'Findings (النتائج)',
                  hintText: 'أدخل النتائج...',
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: impressionController,
                decoration: const InputDecoration(
                  labelText: 'Impression (التشخيص)',
                  hintText: 'أدخل التشخيص...',
                ),
                maxLines: 4,
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
            onPressed: () => Navigator.pop(context, true),
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

      final report = RadiologyReportModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        requestId: request.id,
        findings: findingsController.text.trim().isNotEmpty
            ? findingsController.text.trim()
            : null,
        impression: impressionController.text.trim().isNotEmpty
            ? impressionController.text.trim()
            : null,
        attachments: attachments.isNotEmpty ? attachments : null,
        createdAt: DateTime.now(),
      );

      await _dataService.createRadiologyReport(report);
      await _dataService.updateRadiologyStatus(
        request.id,
        RadiologyStatus.completed,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إضافة التقرير بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        _loadRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إضافة التقرير: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showStatusFilter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('فلترة حسب الحالة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String?>(
              title: const Text('جميع الحالات'),
              value: null,
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() => _filterStatus = value);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String?>(
              title: const Text('مطلوبة'),
              value: 'requested',
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() => _filterStatus = value);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String?>(
              title: const Text('مجدولة'),
              value: 'scheduled',
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() => _filterStatus = value);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String?>(
              title: const Text('مكتملة'),
              value: 'completed',
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() => _filterStatus = value);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String?>(
              title: const Text('ملغاة'),
              value: 'cancelled',
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() => _filterStatus = value);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showModalityFilter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('فلترة حسب النوع'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String?>(
              title: const Text('جميع الأنواع'),
              value: null,
              groupValue: _filterModality,
              onChanged: (value) {
                setState(() => _filterModality = value);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String?>(
              title: const Text('أشعة سينية (X-Ray)'),
              value: 'xray',
              groupValue: _filterModality,
              onChanged: (value) {
                setState(() => _filterModality = value);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String?>(
              title: const Text('أشعة مقطعية (CT)'),
              value: 'ct',
              groupValue: _filterModality,
              onChanged: (value) {
                setState(() => _filterModality = value);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String?>(
              title: const Text('رنين مغناطيسي (MRI)'),
              value: 'mri',
              groupValue: _filterModality,
              onChanged: (value) {
                setState(() => _filterModality = value);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String?>(
              title: const Text('موجات فوق صوتية (US)'),
              value: 'us',
              groupValue: _filterModality,
              onChanged: (value) {
                setState(() => _filterModality = value);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String?>(
              title: const Text('أخرى'),
              value: 'other',
              groupValue: _filterModality,
              onChanged: (value) {
                setState(() => _filterModality = value);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

