import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/data_service.dart';
import '../../models/radiology_model.dart';
import '../../providers/auth_provider_local.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/ui_snackbar.dart';

class PatientRadiologyScreen extends StatefulWidget {
  const PatientRadiologyScreen({super.key});

  @override
  State<PatientRadiologyScreen> createState() => _PatientRadiologyScreenState();
}

class _PatientRadiologyScreenState extends State<PatientRadiologyScreen> {
  final DataService _dataService = DataService();
  bool _loading = false;
  List<RadiologyRequestModel> _requests = [];
  final Map<String, List<RadiologyReportModel>> _reports = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final auth = Provider.of<AuthProviderLocal>(context, listen: false);
      final patient = auth.currentUser;
      final list = await _dataService.getRadiologyRequests(patientId: patient?.id) as List;
      final requests = list.cast<RadiologyRequestModel>();
      final allReports = <String, List<RadiologyReportModel>>{};
      for (final r in requests) {
        final reps = await _dataService.getRadiologyReports(requestId: r.id) as List;
        allReports[r.id] = reps.cast<RadiologyReportModel>();
      }
      setState(() {
        _requests = requests;
        _reports
          ..clear()
          ..addAll(allReports);
      });
    } catch (e) { if (mounted) showFriendlyAuthError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('yyyy-MM-dd HH:mm');
    return Scaffold(
      appBar: AppBar(
        title: const Text('تقارير الأشعة'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              itemCount: _requests.length,
              separatorBuilder: (_, __) => const Divider(height: 0),
              itemBuilder: (context, index) {
                final r = _requests[index];
                final reps = _reports[r.id] ?? const <RadiologyReportModel>[];
                return ExpansionTile(
                  leading: const Icon(Icons.image),
                  title: Text('${r.modality.toUpperCase()} • ${r.bodyPart ?? '-'} • ${r.status.name}'),
                  subtitle: Text('بتاريخ: ${fmt.format(r.requestedAt)}'),
                  children: reps.isEmpty
                      ? const [ListTile(title: Text('لا توجد تقارير حالياً'))]
                      : reps.map((rep) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.description),
                                title: Text(rep.impression ?? 'Report'),
                                subtitle: Text(rep.findings ?? ''),
                              ),
                              if (rep.attachments != null && rep.attachments!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: rep.attachments!.map((url) => _buildAttachmentTile(context, url)).toList(),
                                  ),
                                ),
                            ],
                          );
                        }).toList(),
                );
              },
            ),
    );
  }

  Widget _buildAttachmentTile(BuildContext context, String url) {
    final lower = url.toLowerCase();
    final isPdf = lower.endsWith('.pdf');
    final isImage = lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.contains('/image');

    if (isImage) {
      return InkWell(
        onTap: () => _openImagePreview(url),
        child: Container(
          width: 100,
          height: 100,
          color: Colors.black12,
          child: _buildImage(url, fit: BoxFit.cover),
        ),
      );
    }

    if (isPdf) {
      return OutlinedButton.icon(
        icon: const Icon(Icons.picture_as_pdf),
        label: const Text('PDF'),
        onPressed: () => _openUrl(url),
      );
    }

    return OutlinedButton.icon(
      icon: const Icon(Icons.attach_file),
      label: const Text('ملف'),
      onPressed: () => _openUrl(url),
    );
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
    if (url.startsWith('http')) {
      return Image.network(url, fit: fit);
    }
    if (url.startsWith('/')) {
      return Image.network(url, fit: fit);
    }
    // مسار ملف محلي
    final file = File(url);
    if (file.existsSync()) {
      return Image.file(file, fit: fit);
    }
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
      MaterialPageRoute(
        builder: (_) => _ImagePreviewScreen(imageProvider: provider, tag: url),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = url.startsWith('http') ? Uri.parse(url) : Uri.parse(url.startsWith('/') ? url : 'file://$url');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح الرابط')));
      }
    }
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
}


