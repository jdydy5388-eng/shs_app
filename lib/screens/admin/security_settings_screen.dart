import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/backup_service.dart';
import '../../services/enhanced_audit_service.dart';
import '../../services/encryption_service.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  final BackupService _backupService = BackupService();
  final EnhancedAuditService _auditService = EnhancedAuditService();
  final EncryptionService _encryptionService = EncryptionService();
  
  List<Map<String, dynamic>> _backups = [];
  bool _isLoading = false;
  bool _isEncryptionEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadBackups();
    _checkEncryptionStatus();
  }

  Future<void> _loadBackups() async {
    setState(() => _isLoading = true);
    try {
      final backups = await _backupService.getBackups();
      setState(() {
        _backups = backups;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkEncryptionStatus() async {
    try {
      await _encryptionService.initialize();
      setState(() => _isEncryptionEnabled = true);
    } catch (e) {
      setState(() => _isEncryptionEnabled = false);
    }
  }

  Future<void> _createBackup() async {
    setState(() => _isLoading = true);
    try {
      final backupPath = await _backupService.createBackup();
      if (backupPath != null) {
        await _auditService.logBackupOperation(
          isRestore: false,
          backupPath: backupPath,
          success: true,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إنشاء النسخة الاحتياطية بنجاح')),
          );
          _loadBackups();
        }
      } else {
        throw Exception('فشل إنشاء النسخة الاحتياطية');
      }
    } catch (e) {
      await _auditService.logBackupOperation(
        isRestore: false,
        backupPath: '',
        success: false,
        errorMessage: e.toString(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في إنشاء النسخة الاحتياطية: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _restoreBackup(String backupPath) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الاستعادة'),
        content: const Text('هل أنت متأكد من استعادة هذه النسخة؟ سيتم استبدال جميع البيانات الحالية.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تأكيد', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final success = await _backupService.restoreBackup(backupPath);
      if (success) {
        await _auditService.logBackupOperation(
          isRestore: true,
          backupPath: backupPath,
          success: true,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم استعادة النسخة الاحتياطية بنجاح')),
          );
        }
      } else {
        throw Exception('فشل استعادة النسخة الاحتياطية');
      }
    } catch (e) {
      await _auditService.logBackupOperation(
        isRestore: true,
        backupPath: backupPath,
        success: false,
        errorMessage: e.toString(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في استعادة النسخة الاحتياطية: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات الأمان والخصوصية'),
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
                    const Text(
                      'التشفير',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('تشفير البيانات الحساسة'),
                        Switch(
                          value: _isEncryptionEnabled,
                          onChanged: (value) {
                            setState(() => _isEncryptionEnabled = value);
                            // TODO: تفعيل/تعطيل التشفير
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'يتم تشفير البيانات الحساسة مثل كلمات المرور والمعلومات الطبية',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'النسخ الاحتياطي',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _createBackup,
                          icon: const Icon(Icons.backup),
                          label: const Text('إنشاء نسخة احتياطية'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (_backups.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('لا توجد نسخ احتياطية'),
                        ),
                      )
                    else
                      ..._backups.map((backup) {
                        final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
                        final sizeInMB = (backup['size'] as int) / (1024 * 1024);
                        return ListTile(
                          leading: const Icon(Icons.backup),
                          title: Text(backup['name'] as String),
                          subtitle: Text(
                            '${dateFormat.format(DateTime.fromMillisecondsSinceEpoch(backup['createdAt'] as int))} - ${sizeInMB.toStringAsFixed(2)} MB',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.restore),
                            onPressed: () => _restoreBackup(backup['path'] as String),
                            tooltip: 'استعادة',
                          ),
                        );
                      }),
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
                      'تسجيل العمليات الحساسة',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'يتم تسجيل جميع العمليات الحساسة مثل الوصول إلى البيانات الحساسة، تعديل الصلاحيات، والنسخ الاحتياطي.',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        // TODO: Navigate to audit logs screen
                      },
                      child: const Text('عرض سجلات التدقيق'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

