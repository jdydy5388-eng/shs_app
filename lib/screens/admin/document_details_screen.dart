import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/document_model.dart';
import '../../models/user_model.dart';
import '../../services/data_service.dart';
import '../../utils/auth_helper.dart';
import 'package:uuid/uuid.dart';

class DocumentDetailsScreen extends StatefulWidget {
  final String documentId;

  const DocumentDetailsScreen({super.key, required this.documentId});

  @override
  State<DocumentDetailsScreen> createState() => _DocumentDetailsScreenState();
}

class _DocumentDetailsScreenState extends State<DocumentDetailsScreen> {
  final DataService _dataService = DataService();
  DocumentModel? _document;
  DocumentSignature? _signature;
  bool _isLoading = true;
  bool _isArchiving = false;
  bool _isSigning = false;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    setState(() => _isLoading = true);
    try {
      final document = await _dataService.getDocument(widget.documentId);
      if (document != null && document is DocumentModel) {
        setState(() {
          _document = document as DocumentModel;
        });
        _loadSignature();
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('الوثيقة غير موجودة')),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل الوثيقة: $e')),
        );
      }
    }
  }

  Future<void> _loadSignature() async {
    try {
      final signature = await _dataService.getDocumentSignature(widget.documentId);
      setState(() {
        _signature = signature;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openFile() async {
    if (_document == null || _document!.fileUrl.isEmpty) return;

    try {
      final url = Uri.parse(_document!.fileUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لا يمكن فتح الملف')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في فتح الملف: $e')),
        );
      }
    }
  }

  Future<void> _archiveDocument() async {
    if (_document == null) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('أرشفة الوثيقة'),
        content: const Text('هل أنت متأكد من أرشفة هذه الوثيقة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('أرشف'),
          ),
        ],
      ),
    );

    if (result != true) return;

    setState(() => _isArchiving = true);
    try {
      final currentUser = AuthHelper.getCurrentUser(context);
      await _dataService.updateDocument(
        widget.documentId,
        status: DocumentStatus.archived,
        archivedAt: DateTime.now(),
        archivedBy: currentUser?.id,
      );
      await _loadDocument();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم أرشفة الوثيقة بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في أرشفة الوثيقة: $e')),
        );
      }
    } finally {
      setState(() => _isArchiving = false);
    }
  }

  Future<void> _signDocument() async {
    if (_document == null) return;

    final signatureController = TextEditingController();
    final notesController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('توقيع الوثيقة'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: signatureController,
                decoration: const InputDecoration(
                  labelText: 'التوقيع (نص أو بيانات)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
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
              if (signatureController.text.trim().isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('وقع'),
          ),
        ],
      ),
    );

    if (result != true || signatureController.text.trim().isEmpty) return;

    setState(() => _isSigning = true);
    try {
      final currentUser = AuthHelper.getCurrentUser(context);
      if (currentUser == null) return;

      final signature = DocumentSignature(
        id: const Uuid().v4(),
        documentId: widget.documentId,
        signedBy: currentUser.id,
        signedByName: currentUser.name,
        signatureData: signatureController.text.trim(),
        signedAt: DateTime.now(),
        notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
      );

      await _dataService.createDocumentSignature(signature);
      await _dataService.updateDocument(
        widget.documentId,
        signatureId: signature.id,
        signedAt: signature.signedAt,
        signedBy: signature.signedByName,
      );
      await _loadDocument();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم توقيع الوثيقة بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في توقيع الوثيقة: $e')),
        );
      }
    } finally {
      setState(() => _isSigning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_document == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الوثيقة')),
        body: const Center(child: Text('الوثيقة غير موجودة')),
      );
    }

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm', 'ar');

    final categoryText = {
      DocumentCategory.medicalRecord: 'سجل طبي',
      DocumentCategory.labResult: 'نتيجة مختبرية',
      DocumentCategory.radiologyReport: 'تقرير أشعة',
      DocumentCategory.prescription: 'وصفة طبية',
      DocumentCategory.surgeryReport: 'تقرير عملية',
      DocumentCategory.dischargeSummary: 'ملخص الخروج',
      DocumentCategory.consentForm: 'نموذج موافقة',
      DocumentCategory.insuranceDocument: 'وثيقة تأمين',
      DocumentCategory.administrative: 'إداري',
      DocumentCategory.other: 'أخرى',
    }[_document!.category]!;

    final statusText = {
      DocumentStatus.draft: 'مسودة',
      DocumentStatus.active: 'نشط',
      DocumentStatus.archived: 'مؤرشف',
      DocumentStatus.deleted: 'محذوف',
    }[_document!.status]!;

    final accessLevelText = {
      DocumentAccessLevel.private: 'خاص',
      DocumentAccessLevel.shared: 'مشترك',
      DocumentAccessLevel.department: 'القسم',
      DocumentAccessLevel.hospital: 'المستشفى',
    }[_document!.accessLevel]!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الوثيقة'),
        actions: [
          if (_document!.status != DocumentStatus.archived)
            IconButton(
              icon: const Icon(Icons.archive),
              onPressed: _isArchiving ? null : _archiveDocument,
              tooltip: 'أرشف',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _document!.title,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    if (_document!.description != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _document!.description!,
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'معلومات الوثيقة',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow('الفئة', categoryText),
                    _buildInfoRow('الحالة', statusText),
                    _buildInfoRow('مستوى الوصول', accessLevelText),
                    if (_document!.patientName != null)
                      _buildInfoRow('المريض', _document!.patientName!),
                    if (_document!.doctorName != null)
                      _buildInfoRow('الطبيب', _document!.doctorName!),
                    _buildInfoRow('تاريخ الإنشاء', dateFormat.format(_document!.createdAt)),
                    if (_document!.updatedAt != null)
                      _buildInfoRow('آخر تحديث', dateFormat.format(_document!.updatedAt!)),
                    if (_document!.fileSize != null)
                      _buildInfoRow('حجم الملف', '${(_document!.fileSize! / 1024).toStringAsFixed(2)} KB'),
                  ],
                ),
              ),
            ),
            if (_document!.tags != null && _document!.tags!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'العلامات',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _document!.tags!.map((tag) => Chip(
                          label: Text(tag),
                        )).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (_signature != null) ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.verified, color: Colors.green),
                          const SizedBox(width: 8),
                          const Text(
                            'موقعة',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow('وقع بواسطة', _signature!.signedByName),
                      _buildInfoRow('تاريخ التوقيع', dateFormat.format(_signature!.signedAt)),
                      if (_signature!.notes != null)
                        _buildInfoRow('ملاحظات', _signature!.notes!),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _openFile,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('فتح الملف'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                if (_document!.status != DocumentStatus.archived && _signature == null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSigning ? null : _signDocument,
                      icon: _isSigning
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.edit),
                      label: const Text('وقع الوثيقة'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}

