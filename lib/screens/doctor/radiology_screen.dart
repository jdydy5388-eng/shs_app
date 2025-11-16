import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../services/data_service.dart';
import '../../models/radiology_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider_local.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../utils/ui_snackbar.dart';

class RadiologyScreen extends StatefulWidget {
  const RadiologyScreen({super.key});

  @override
  State<RadiologyScreen> createState() => _RadiologyScreenState();
}

class _RadiologyScreenState extends State<RadiologyScreen> {
  final DataService _dataService = DataService();
  bool _loading = false;
  List<RadiologyRequestModel> _requests = [];
  final Map<String, List<RadiologyReportModel>> _reports = {};
  String? _filterStatus;   // requested/scheduled/completed/cancelled or null = all
  String? _filterModality; // xray/ct/mri/us/other or null = all

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
        final doctor = auth.currentUser as UserModel;
        final req = RadiologyRequestModel(
          id: const Uuid().v4(),
          doctorId: doctor.id,
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
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
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
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.image),
                      label: const Text('اختر صورة'),
                      onPressed: () async {
                        try {
                          final picker = ImagePicker();
                          final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                          if (picked != null) {
                            final bytes = await picked.readAsBytes();
                            final url = await DataService().uploadFile(
                              filename: picked.name,
                              bytes: bytes,
                              contentType: 'image/${picked.name.toLowerCase().endsWith('png') ? 'png' : 'jpeg'}',
                            );
                            uploadedUrls.add(url);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفع الصورة')));
                            }
                          }
                        } catch (e) { if (mounted) showFriendlyAuthError(context, e); }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('التقاط كاميرا'),
                      onPressed: () async {
                        try {
                          final picker = ImagePicker();
                          final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
                          if (picked != null) {
                            final bytes = await picked.readAsBytes();
                            final url = await DataService().uploadFile(
                              filename: picked.name,
                              bytes: bytes,
                              contentType: 'image/${picked.name.toLowerCase().endsWith('png') ? 'png' : 'jpeg'}',
                            );
                            uploadedUrls.add(url);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفع الصورة من الكاميرا')));
                            }
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الرفع: $e')));
                          }
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
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
                              final url = await DataService().uploadFile(
                                filename: f.name,
                                bytes: f.bytes!,
                                contentType: _inferContentType(f.name),
                              );
                              uploadedUrls.add(url);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفع الملف')));
                              }
                            }
                          }
                        } catch (e) { if (mounted) showFriendlyAuthError(context, e); }
                      },
                    ),
                  ),
                ],
              ),
              if (uploadedUrls.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('المرفقات:', style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 6),
                        Wrap(
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
                      ],
                    ),
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
          id: const Uuid().v4(),
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
    // إذا كان رابطاً لخادم التخزين، نستخدم رابطاً موقّتاً
    final bool isStorage = url.startsWith('/api/storage/files/');
    if (isStorage) {
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
    if (url.startsWith('http') || url.startsWith('/')) {
      return Image.network(url, fit: fit);
    }
    final file = File(url);
    if (file.existsSync()) return Image.file(file, fit: fit);
    return const Icon(Icons.broken_image);
  }

  Future<void> _openImagePreview(String url) async {
    ImageProvider provider;
    if (url.startsWith('/api/storage/files/')) {
      final signed = await _dataService.getSignedFileUrl(url, expiresSeconds: 300);
      provider = NetworkImage(signed);
    } else if (url.startsWith('http') || url.startsWith('/')) {
      provider = NetworkImage(url);
    } else {
      final file = File(url);
      provider = FileImage(file);
    }
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _ImagePreviewScreen(imageProvider: provider, tag: url)),
    );
  }
}

class _ImagePreviewScreen extends StatelessWidget {
  const _ImagePreviewScreen({required this.imageProvider, required this.tag});

  final ImageProvider imageProvider;
  final String tag;

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
          child: Image(
            image: imageProvider,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

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
          child: Image(
            image: imageProvider,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

}


