import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/data_service.dart';
import '../../models/radiology_model.dart';
import '../../providers/auth_provider_local.dart';
import 'package:file_picker/file_picker.dart';
import '../../utils/ui_snackbar.dart';

class RadiologyWebScreen extends StatefulWidget {
  const RadiologyWebScreen({super.key});

  @override
  State<RadiologyWebScreen> createState() => _RadiologyWebScreenState();
}

class _RadiologyWebScreenState extends State<RadiologyWebScreen> {
  final DataService _dataService = DataService();
  bool _loading = false;
  List<RadiologyRequestModel> _requests = [];
  final Map<String, List<RadiologyReportModel>> _reports = {};
  String? _filterStatus;
  String? _filterModality;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final auth = Provider.of<AuthProviderLocal>(context, listen: false);
      final doctor = auth.currentUser;
      final list = await _dataService.getRadiologyRequests(
        doctorId: doctor?.id,
        status: _filterStatus,
        modality: _filterModality,
      ) as List;
      final reqs = list.cast<RadiologyRequestModel>();
      final repMap = <String, List<RadiologyReportModel>>{};
      for (final r in reqs) {
        final reps = await _dataService.getRadiologyReports(requestId: r.id) as List;
        repMap[r.id] = reps.cast<RadiologyReportModel>();
      }
      setState(() {
        _requests = reqs;
        _reports
          ..clear()
          ..addAll(repMap);
      });
    } catch (e) {
      if (mounted) showFriendlyAuthError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('yyyy-MM-dd HH:mm');
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلبات الأشعة (ويب)'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(icon: const Icon(Icons.add), onPressed: _openCreateDialog),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildFilters(),
                const Divider(height: 0),
                Expanded(
                  child: ListView.separated(
                    itemCount: _requests.length,
                    separatorBuilder: (_, __) => const Divider(height: 0),
                    itemBuilder: (context, index) {
                      final r = _requests[index];
                      final reps = _reports[r.id] ?? const <RadiologyReportModel>[];
                      return ExpansionTile(
                        leading: const Icon(Icons.image_search),
                        title: Text('${r.modality.toUpperCase()} • ${r.bodyPart ?? '-'}'),
                        subtitle: Text('المريض: ${r.patientName} • ${fmt.format(r.requestedAt)}'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'report') {
                              await _openAddReport(r);
                            } else if (value == 'schedule') {
                              final now = DateTime.now().add(const Duration(hours: 4));
                              await _dataService.updateRadiologyRequest(r.id, scheduledAt: now);
                              await _dataService.updateRadiologyStatus(r.id, RadiologyStatus.scheduled.toString().split('.').last);
                              await _load();
                            } else if (value == 'cancel') {
                              await _dataService.updateRadiologyStatus(r.id, RadiologyStatus.cancelled.toString().split('.').last);
                              await _load();
                            } else if (value == 'refresh') {
                              await _load();
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'report', child: Text('إضافة تقرير')),
                            PopupMenuItem(value: 'schedule', child: Text('جدولة')),
                            PopupMenuItem(value: 'cancel', child: Text('إلغاء')),
                            PopupMenuItem(value: 'refresh', child: Text('تحديث')),
                          ],
                        ),
                        children: [
                          if (reps.isEmpty)
                            const ListTile(
                              leading: Icon(Icons.info_outline),
                              title: Text('لا توجد تقارير بعد'),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: reps.map((rep) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      ListTile(
                                        leading: const Icon(Icons.description),
                                        title: Text(rep.impression ?? 'Report'),
                                        subtitle: Text(rep.findings ?? ''),
                                      ),
                                      if (rep.attachments != null && rep.attachments!.isNotEmpty)
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: rep.attachments!.map((u) {
                                            return InkWell(
                                              onTap: () => _openImagePreview(u),
                                              child: Container(
                                                width: 90,
                                                height: 90,
                                                color: Colors.black12,
                                                child: _buildImage(u, fit: BoxFit.cover),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      const SizedBox(height: 8),
                                      const Divider(height: 0),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilters() {
    final statusItems = <DropdownMenuItem<String?>>[
      const DropdownMenuItem(value: null, child: Text('كل الحالات')),
      const DropdownMenuItem(value: 'requested', child: Text('Requested')),
      const DropdownMenuItem(value: 'scheduled', child: Text('Scheduled')),
      const DropdownMenuItem(value: 'completed', child: Text('Completed')),
      const DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
    ];
    final modalityItems = <DropdownMenuItem<String?>>[
      const DropdownMenuItem(value: null, child: Text('كل الأنواع')),
      const DropdownMenuItem(value: 'xray', child: Text('X-Ray')),
      const DropdownMenuItem(value: 'ct', child: Text('CT')),
      const DropdownMenuItem(value: 'mri', child: Text('MRI')),
      const DropdownMenuItem(value: 'us', child: Text('Ultrasound')),
      const DropdownMenuItem(value: 'other', child: Text('Other')),
    ];

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String?>(
              value: _filterStatus,
              items: statusItems,
              onChanged: (v) async {
                setState(() => _filterStatus = v);
                await _load();
              },
              decoration: const InputDecoration(
                labelText: 'الحالة',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String?>(
              value: _filterModality,
              items: modalityItems,
              onChanged: (v) async {
                setState(() => _filterModality = v);
                await _load();
              },
              decoration: const InputDecoration(
                labelText: 'النوع',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCreateDialog() async {
    final patientIdController = TextEditingController();
    final patientNameController = TextEditingController();
    final modality = ValueNotifier<String>('xray');
    final bodyPartController = TextEditingController();
    final notesController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('طلب أشعة جديد'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: patientIdController, decoration: const InputDecoration(labelText: 'معرّف المريض')),
              TextField(controller: patientNameController, decoration: const InputDecoration(labelText: 'اسم المريض')),
              const SizedBox(height: 8),
              ValueListenableBuilder<String>(
                valueListenable: modality,
                builder: (_, value, __) => DropdownButtonFormField<String>(
                  value: value,
                  decoration: const InputDecoration(labelText: 'النوع'),
                  onChanged: (v) => modality.value = v ?? 'xray',
                  items: const [
                    DropdownMenuItem(value: 'xray', child: Text('X-Ray')),
                    DropdownMenuItem(value: 'ct', child: Text('CT')),
                    DropdownMenuItem(value: 'mri', child: Text('MRI')),
                    DropdownMenuItem(value: 'us', child: Text('Ultrasound')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                ),
              ),
              TextField(controller: bodyPartController, decoration: const InputDecoration(labelText: 'الجزء/المنطقة')),
              TextField(controller: notesController, decoration: const InputDecoration(labelText: 'ملاحظات'), maxLines: 3),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ')),
        ],
      ),
    );

    if (result == true && patientIdController.text.trim().isNotEmpty) {
      try {
        final auth = Provider.of<AuthProviderLocal>(context, listen: false);
        final doctor = auth.currentUser;
        final req = RadiologyRequestModel(
          id: _dataService.generateId(),
          doctorId: doctor?.id ?? '',
          patientId: patientIdController.text.trim(),
          patientName: patientNameController.text.trim().isEmpty ? 'مريض' : patientNameController.text.trim(),
          modality: modality.value,
          bodyPart: bodyPartController.text.trim().isEmpty ? null : bodyPartController.text.trim(),
          status: RadiologyStatus.requested,
          requestedAt: DateTime.now(),
          notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
        );
        await _dataService.createRadiologyRequest(req);
        await _load();
      } catch (e) { if (mounted) showFriendlyAuthError(context, e); }
    }
  }

  Future<void> _openAddReport(RadiologyRequestModel request) async {
    final findingsController = TextEditingController();
    final impressionController = TextEditingController();
    final List<String> uploadedUrls = [];

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة تقرير أشعة'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: findingsController, decoration: const InputDecoration(labelText: 'Findings'), maxLines: 3),
              TextField(controller: impressionController, decoration: const InputDecoration(labelText: 'Impression'), maxLines: 3),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.attach_file),
                label: const Text('اختر ملف'),
                onPressed: () async {
                  try {
                    final res = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
                      withData: true,
                    );
                    if (res != null && res.files.isNotEmpty) {
                      final f = res.files.first;
                      if (f.bytes != null) {
                        final url = await _dataService.uploadFile(
                          filename: f.name,
                          bytes: f.bytes!,
                          contentType: _inferContentType(f.name),
                        );
                        uploadedUrls.add(url);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفع الملف')));
                        }
                        setState(() {});
                      }
                    }
                  } catch (e) { if (mounted) showFriendlyAuthError(context, e); }
                },
              ),
              if (uploadedUrls.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: uploadedUrls.map((u) {
                      return InkWell(
                        onTap: () => _openImagePreview(u),
                        child: Container(
                          width: 80,
                          height: 80,
                          color: Colors.black12,
                          child: _buildImage(u, fit: BoxFit.cover),
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ')),
        ],
      ),
    );

    if (result == true) {
      try {
        final report = RadiologyReportModel(
          id: _dataService.generateId(),
          requestId: request.id,
          findings: findingsController.text.trim().isEmpty ? null : findingsController.text.trim(),
          impression: impressionController.text.trim().isEmpty ? null : impressionController.text.trim(),
          attachments: uploadedUrls.isEmpty ? null : uploadedUrls,
          createdAt: DateTime.now(),
        );
        await _dataService.createRadiologyReport(report);
        await _dataService.updateRadiologyStatus(request.id, RadiologyStatus.completed.toString().split('.').last);
        await _load();
      } catch (e) { if (mounted) showFriendlyAuthError(context, e); }
    }
  }

  String _inferContentType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    return 'application/octet-stream';
  }

  Widget _buildImage(String url, {BoxFit fit = BoxFit.contain}) {
    if (url.startsWith('/api/storage/files/')) {
      return FutureBuilder<String>(
        future: _dataService.getSignedFileUrl(url, expiresSeconds: 300),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)));
          }
          if (!snap.hasData) return const Icon(Icons.broken_image);
          return Image.network(snap.data!, fit: fit);
        },
      );
    }
    return Image.network(url, fit: fit);
  }

  Future<void> _openImagePreview(String url) async {
    String finalUrl = url;
    if (url.startsWith('/api/storage/files/')) {
      finalUrl = await _dataService.getSignedFileUrl(url, expiresSeconds: 300);
    }
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _ImagePreviewWeb(url: finalUrl)),
    );
  }
}

class _ImagePreviewWeb extends StatelessWidget {
  const _ImagePreviewWeb({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('معاينة', style: TextStyle(color: Colors.white)),
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }
}


