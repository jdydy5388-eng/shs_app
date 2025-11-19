import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../models/document_model.dart';
import '../../models/user_model.dart';
import '../../services/data_service.dart';
import '../../utils/auth_helper.dart';
import 'document_details_screen.dart';
import 'upload_document_screen.dart';

class DocumentsManagementScreen extends StatefulWidget {
  const DocumentsManagementScreen({super.key});

  @override
  State<DocumentsManagementScreen> createState() => _DocumentsManagementScreenState();
}

class _DocumentsManagementScreenState extends State<DocumentsManagementScreen> {
  final DataService _dataService = DataService();
  List<DocumentModel> _documents = [];
  bool _isLoading = true;
  String _searchQuery = '';
  DocumentCategory? _filterCategory;
  DocumentStatus? _filterStatus;
  DocumentAccessLevel? _filterAccessLevel;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    try {
      final documents = await _dataService.getDocuments(
        category: _filterCategory,
        status: _filterStatus,
        accessLevel: _filterAccessLevel,
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
      );
      setState(() {
        _documents = documents.cast<DocumentModel>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل الوثائق: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الوثائق'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilters,
            tooltip: 'فلترة',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDocuments,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadDocuments,
                    child: _documents.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.folder_open,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'لا توجد وثائق',
                                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _documents.length,
                            itemBuilder: (context, index) {
                              return _buildDocumentCard(_documents[index]);
                            },
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UploadDocumentScreen()),
        ).then((_) => _loadDocuments()),
        icon: const Icon(Icons.upload_file),
        label: const Text('رفع وثيقة'),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'بحث في الوثائق...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() => _searchQuery = '');
                    _loadDocuments();
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onChanged: (value) {
          setState(() => _searchQuery = value);
          _loadDocuments();
        },
      ),
    );
  }

  Widget _buildDocumentCard(DocumentModel document) {
    final dateFormat = DateFormat('yyyy-MM-dd', 'ar');
    
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
    }[document.category]!;

    final categoryIcon = {
      DocumentCategory.medicalRecord: Icons.medical_services,
      DocumentCategory.labResult: Icons.science,
      DocumentCategory.radiologyReport: Icons.image,
      DocumentCategory.prescription: Icons.description,
      DocumentCategory.surgeryReport: Icons.medical_services,
      DocumentCategory.dischargeSummary: Icons.summarize,
      DocumentCategory.consentForm: Icons.assignment,
      DocumentCategory.insuranceDocument: Icons.card_membership,
      DocumentCategory.administrative: Icons.folder,
      DocumentCategory.other: Icons.insert_drive_file,
    }[document.category]!;

    final statusColor = {
      DocumentStatus.draft: Colors.grey,
      DocumentStatus.active: Colors.green,
      DocumentStatus.archived: Colors.orange,
      DocumentStatus.deleted: Colors.red,
    }[document.status]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.withValues(alpha: 0.2),
          child: Icon(categoryIcon, color: Colors.blue),
        ),
        title: Text(
          document.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الفئة: $categoryText'),
            if (document.patientName != null) Text('المريض: ${document.patientName}'),
            if (document.doctorName != null) Text('الطبيب: ${document.doctorName}'),
            Text('التاريخ: ${dateFormat.format(document.createdAt)}'),
            if (document.tags != null && document.tags!.isNotEmpty)
              Wrap(
                spacing: 4,
                children: document.tags!.take(3).map((tag) => Chip(
                  label: Text(tag, style: const TextStyle(fontSize: 10)),
                  padding: EdgeInsets.zero,
                )).toList(),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                document.status == DocumentStatus.active
                    ? 'نشط'
                    : document.status == DocumentStatus.archived
                        ? 'مؤرشف'
                        : document.status == DocumentStatus.draft
                            ? 'مسودة'
                            : 'محذوف',
                style: TextStyle(
                  fontSize: 10,
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (document.signatureId != null)
              const Icon(Icons.verified, color: Colors.green, size: 16),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DocumentDetailsScreen(documentId: document.id),
          ),
        ).then((_) => _loadDocuments()),
      ),
    );
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'فلترة الوثائق',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<DocumentCategory?>(
                value: _filterCategory,
                decoration: const InputDecoration(
                  labelText: 'الفئة',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('جميع الفئات')),
                  ...DocumentCategory.values.map((cat) {
                    final catText = {
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
                    }[cat]!;
                    return DropdownMenuItem(value: cat, child: Text(catText));
                  }),
                ],
                onChanged: (value) {
                  setModalState(() => _filterCategory = value);
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<DocumentStatus?>(
                value: _filterStatus,
                decoration: const InputDecoration(
                  labelText: 'الحالة',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('جميع الحالات')),
                  const DropdownMenuItem(value: DocumentStatus.draft, child: Text('مسودة')),
                  const DropdownMenuItem(value: DocumentStatus.active, child: Text('نشط')),
                  const DropdownMenuItem(value: DocumentStatus.archived, child: Text('مؤرشف')),
                ],
                onChanged: (value) {
                  setModalState(() => _filterStatus = value);
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setModalState(() {
                        _filterCategory = null;
                        _filterStatus = null;
                        _filterAccessLevel = null;
                      });
                    },
                    child: const Text('إعادة تعيين'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _loadDocuments();
                    },
                    child: const Text('تطبيق'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

