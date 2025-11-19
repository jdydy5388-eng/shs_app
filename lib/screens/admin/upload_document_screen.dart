import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import '../../models/document_model.dart';
import '../../models/user_model.dart';
import '../../services/data_service.dart';
import '../../utils/auth_helper.dart';
import 'dart:io';

class UploadDocumentScreen extends StatefulWidget {
  const UploadDocumentScreen({super.key});

  @override
  State<UploadDocumentScreen> createState() => _UploadDocumentScreenState();
}

class _UploadDocumentScreenState extends State<UploadDocumentScreen> {
  final DataService _dataService = DataService();
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();

  DocumentCategory _selectedCategory = DocumentCategory.other;
  DocumentStatus _selectedStatus = DocumentStatus.active;
  DocumentAccessLevel _selectedAccessLevel = DocumentAccessLevel.private;
  String? _selectedPatientId;
  String? _selectedDoctorId;
  List<String> _selectedSharedUserIds = [];
  File? _selectedFile;
  String? _fileUrl;
  bool _isUploading = false;
  bool _isLoading = false;
  List<UserModel> _patients = [];
  List<UserModel> _doctors = [];
  List<UserModel> _users = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final allUsers = await _dataService.getUsers();
      setState(() {
        _patients = allUsers.where((u) => u is UserModel && u.role == UserRole.patient).cast<UserModel>().toList();
        _doctors = allUsers.where((u) => u is UserModel && u.role == UserRole.doctor).cast<UserModel>().toList();
        _users = allUsers.cast<UserModel>().toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل المستخدمين: $e')),
        );
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
        });
        await _uploadFile();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في اختيار الملف: $e')),
        );
      }
    }
  }

  Future<void> _uploadFile() async {
    if (_selectedFile == null) return;

    setState(() => _isUploading = true);
    try {
      final bytes = await _selectedFile!.readAsBytes();
      final fileName = _selectedFile!.path.split('/').last;
      final fileType = fileName.split('.').last.toLowerCase();

      _fileUrl = await _dataService.uploadFile(
        filename: fileName,
        bytes: bytes,
        contentType: _getContentType(fileType),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم رفع الملف بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في رفع الملف: $e')),
        );
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  String? _getContentType(String fileType) {
    final types = {
      'pdf': 'application/pdf',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'doc': 'application/msword',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    };
    return types[fileType.toLowerCase()];
  }

  Future<void> _saveDocument() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fileUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار ملف للرفع')),
      );
      return;
    }

    final currentUser = AuthHelper.getCurrentUser(context);
    if (currentUser == null) return;

    final selectedPatient = _patients.firstWhere(
      (p) => p.id == _selectedPatientId,
      orElse: () => _patients.first,
    );

    final selectedDoctor = _selectedDoctorId != null
        ? _doctors.firstWhere(
            (d) => d.id == _selectedDoctorId,
            orElse: () => _doctors.first,
          )
        : null;

    final tags = _tagsController.text.trim().isEmpty
        ? null
        : _tagsController.text.trim().split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();

    final document = DocumentModel(
      id: const Uuid().v4(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      category: _selectedCategory,
      status: _selectedStatus,
      accessLevel: _selectedAccessLevel,
      patientId: _selectedPatientId,
      patientName: _selectedPatientId != null ? selectedPatient.name : null,
      doctorId: _selectedDoctorId,
      doctorName: _selectedDoctorId != null ? selectedDoctor?.name : null,
      sharedWithUserIds: _selectedSharedUserIds.isEmpty ? null : _selectedSharedUserIds,
      tags: tags,
      fileUrl: _fileUrl!,
      fileName: _selectedFile!.path.split('/').last,
      fileType: _selectedFile!.path.split('.').last.toLowerCase(),
      fileSize: await _selectedFile!.length(),
      createdBy: currentUser.id,
      createdAt: DateTime.now(),
    );

    try {
      await _dataService.createDocument(document);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ الوثيقة بنجاح')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في حفظ الوثيقة: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('رفع وثيقة جديدة'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'عنوان الوثيقة *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value?.isEmpty ?? true ? 'يرجى إدخال عنوان الوثيقة' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'الوصف',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<DocumentCategory>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'الفئة *',
                        border: OutlineInputBorder(),
                      ),
                      items: DocumentCategory.values.map((cat) {
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
                      }).toList(),
                      onChanged: (value) => setState(() => _selectedCategory = value!),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<DocumentStatus>(
                      value: _selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'الحالة *',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: DocumentStatus.draft, child: Text('مسودة')),
                        DropdownMenuItem(value: DocumentStatus.active, child: Text('نشط')),
                        DropdownMenuItem(value: DocumentStatus.archived, child: Text('مؤرشف')),
                      ],
                      onChanged: (value) => setState(() => _selectedStatus = value!),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<DocumentAccessLevel>(
                      value: _selectedAccessLevel,
                      decoration: const InputDecoration(
                        labelText: 'مستوى الوصول *',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: DocumentAccessLevel.private, child: Text('خاص')),
                        DropdownMenuItem(value: DocumentAccessLevel.shared, child: Text('مشترك')),
                        DropdownMenuItem(value: DocumentAccessLevel.department, child: Text('القسم')),
                        DropdownMenuItem(value: DocumentAccessLevel.hospital, child: Text('المستشفى')),
                      ],
                      onChanged: (value) => setState(() => _selectedAccessLevel = value!),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String?>(
                      value: _selectedPatientId,
                      decoration: const InputDecoration(
                        labelText: 'المريض',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('لا يوجد')),
                        ..._patients.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))),
                      ],
                      onChanged: (value) => setState(() => _selectedPatientId = value),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String?>(
                      value: _selectedDoctorId,
                      decoration: const InputDecoration(
                        labelText: 'الطبيب',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('لا يوجد')),
                        ..._doctors.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))),
                      ],
                      onChanged: (value) => setState(() => _selectedDoctorId = value),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _tagsController,
                      decoration: const InputDecoration(
                        labelText: 'العلامات (مفصولة بفواصل)',
                        border: OutlineInputBorder(),
                        hintText: 'مثال: تقرير، فحص، طوارئ',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'الملف',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            if (_selectedFile != null)
                              Text('الملف المختار: ${_selectedFile!.path.split('/').last}'),
                            if (_fileUrl != null)
                              Text(
                                'تم الرفع بنجاح',
                                style: TextStyle(color: Colors.green[700]),
                              ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: _isUploading ? null : _pickFile,
                              icon: _isUploading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.upload_file),
                              label: Text(_isUploading ? 'جاري الرفع...' : 'اختر ملف'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saveDocument,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('حفظ الوثيقة'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

