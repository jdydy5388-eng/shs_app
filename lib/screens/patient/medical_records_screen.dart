import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../models/medical_record_model.dart';
import '../../providers/auth_provider_local.dart';
import '../../services/data_service.dart';
import 'package:file_picker/file_picker.dart';

class MedicalRecordsScreen extends StatefulWidget {
  const MedicalRecordsScreen({super.key});

  @override
  State<MedicalRecordsScreen> createState() => _MedicalRecordsScreenState();
}

class _MedicalRecordsScreenState extends State<MedicalRecordsScreen> {
  final DataService _dataService = DataService();
  List<MedicalRecordModel> _records = [];
  bool _isLoading = true;

  String get _patientId {
    final authProvider = Provider.of<AuthProviderLocal>(context, listen: false);
    return authProvider.currentUser?.id ?? '';
  }

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    try {
      final records = await _dataService.getMedicalRecords(patientId: _patientId);
      setState(() {
        _records = records.cast<MedicalRecordModel>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        final msg = _formatErrorMessage(e, fallback: 'تعذّر تحميل السجل الصحي. حاول لاحقاً.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة السجل الصحي والتقارير'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddRecordDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRecords,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_open_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'لا توجد سجلات طبية',
                          style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadRecords,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _records.length,
                    itemBuilder: (context, index) {
                      final record = _records[index];
                      return _buildRecordCard(record);
                    },
                  ),
                ),
    );
  }

  Widget _buildRecordCard(MedicalRecordModel record) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getRecordColor(record.type).withValues(alpha: 0.2),
          child: Icon(_getRecordIcon(record.type), color: _getRecordColor(record.type)),
        ),
        title: Text(
          record.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('yyyy-MM-dd').format(record.date)),
            if (record.doctorName != null) Text('الطبيب: ${record.doctorName}'),
            if (record.fileUrls != null && record.fileUrls!.isNotEmpty)
              Text(
                '${record.fileUrls!.length} ملف مرفق',
                style: const TextStyle(color: Colors.blue, fontSize: 12),
              ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('النوع: ${_getRecordTypeName(record.type)}'),
                const SizedBox(height: 8),
                Text('الوصف: ${record.description}'),
                if (record.fileUrls != null && record.fileUrls!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'الملفات المرفقة:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...record.fileUrls!.map((url) => Card(
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
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddRecordDialog() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    RecordType? selectedType = RecordType.note;
    DateTime selectedDate = DateTime.now();
    List<String> filePaths = [];

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('رفع تقرير طبي جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<RecordType>(
                  decoration: const InputDecoration(
                    labelText: 'نوع التقرير *',
                    border: OutlineInputBorder(),
                  ),
                  value: selectedType,
                  items: RecordType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(_getRecordTypeName(type)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedType = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'العنوان *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'الوصف *',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: Text('التاريخ: ${DateFormat('yyyy-MM-dd').format(selectedDate)}'),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => selectedDate = date);
                    }
                  },
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.upload_file),
                  label: Text(filePaths.isEmpty ? 'رفع ملفات' : '${filePaths.length} ملف مرفق'),
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(
                      allowMultiple: true,
                      type: FileType.any,
                    );
                    if (result != null && result.files.isNotEmpty) {
                      setState(() {
                        filePaths = result.files.map((file) => file.name).toList();
                      });
                    }
                  },
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
                if (titleController.text.trim().isEmpty ||
                    descriptionController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى ملء جميع الحقول المطلوبة')),
                  );
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    if (result == true && selectedType != null) {
      try {
        final record = MedicalRecordModel(
          id: const Uuid().v4(),
          patientId: _patientId,
          type: selectedType!,
          title: titleController.text.trim(),
          description: descriptionController.text.trim(),
          date: selectedDate,
          fileUrls: filePaths.isEmpty ? null : filePaths,
          createdAt: DateTime.now(),
        );

        await _dataService.addMedicalRecord(record);
        await _loadRecords();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم رفع التقرير بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_formatErrorMessage(e, fallback: 'تعذّر رفع التقرير. حاول لاحقاً.')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  IconData _getRecordIcon(RecordType type) {
    switch (type) {
      case RecordType.diagnosis:
        return Icons.medical_services;
      case RecordType.labResult:
        return Icons.science;
      case RecordType.xray:
        return Icons.broken_image;
      case RecordType.prescription:
        return Icons.description;
      case RecordType.vaccination:
        return Icons.vaccines;
      case RecordType.surgery:
        return Icons.healing;
      default:
        return Icons.note;
    }
  }

  Color _getRecordColor(RecordType type) {
    switch (type) {
      case RecordType.diagnosis:
        return Colors.blue;
      case RecordType.labResult:
        return Colors.green;
      case RecordType.xray:
        return Colors.purple;
      case RecordType.prescription:
        return Colors.orange;
      case RecordType.vaccination:
        return Colors.teal;
      case RecordType.surgery:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getRecordTypeName(RecordType type) {
    switch (type) {
      case RecordType.diagnosis:
        return 'تشخيص';
      case RecordType.labResult:
        return 'نتائج تحاليل';
      case RecordType.xray:
        return 'أشعة';
      case RecordType.prescription:
        return 'وصفة طبية';
      case RecordType.vaccination:
        return 'تطعيم';
      case RecordType.surgery:
        return 'عملية جراحية';
      default:
        return 'ملاحظة';
    }
  }

  String _formatErrorMessage(Object e, {required String fallback}) {
    final raw = e.toString();
    final cleaned = raw.startsWith('Exception: ')
        ? raw.substring('Exception: '.length).trim()
        : raw.trim();
    return cleaned.isEmpty ? fallback : cleaned;
  }
}
