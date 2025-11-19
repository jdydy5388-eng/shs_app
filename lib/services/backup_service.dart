import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';
import 'local_database_service.dart';
import '../logger/app_logger.dart';

/// خدمة النسخ الاحتياطي التلقائي
class BackupService {
  static final BackupService _instance = BackupService._internal();
  factory BackupService() => _instance;
  BackupService._internal();

  final LocalDatabaseService _db = LocalDatabaseService();

  /// إنشاء نسخة احتياطية من قاعدة البيانات
  Future<String?> createBackup() async {
    try {
      final db = await _db.database;
      final dbPath = db.path;

      // الحصول على مجلد التطبيق
      final appDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory(path.join(appDir.path, 'backups'));
      
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      // اسم الملف مع التاريخ والوقت
      final dateFormat = DateFormat('yyyy-MM-dd_HH-mm-ss');
      final timestamp = dateFormat.format(DateTime.now());
      final backupFileName = 'shs_backup_$timestamp.db';
      final backupPath = path.join(backupDir.path, backupFileName);

      // نسخ قاعدة البيانات
      final sourceFile = File(dbPath);
      final backupFile = File(backupPath);
      await sourceFile.copy(backupPath);

      // حذف النسخ القديمة (الاحتفاظ بآخر 10 نسخ)
      await _cleanOldBackups(backupDir);

      AppLogger.info('Backup created successfully: $backupPath');
      return backupPath;
    } catch (e, stackTrace) {
      AppLogger.error('Create backup error', e, stackTrace);
      return null;
    }
  }

  /// حذف النسخ القديمة (الاحتفاظ بآخر N نسخة)
  Future<void> _cleanOldBackups(Directory backupDir, {int keepCount = 10}) async {
    try {
      final files = backupDir.listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.db'))
          .toList();

      // ترتيب حسب تاريخ التعديل (الأحدث أولاً)
      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      // حذف النسخ الزائدة
      if (files.length > keepCount) {
        for (var i = keepCount; i < files.length; i++) {
          await files[i].delete();
        }
      }
    } catch (e) {
      AppLogger.error('Clean old backups error', e);
    }
  }

  /// استعادة نسخة احتياطية
  Future<bool> restoreBackup(String backupPath) async {
    try {
      final db = await _db.database;
      final dbPath = db.path;

      // إغلاق الاتصال الحالي
      await db.close();

      // نسخ النسخة الاحتياطية إلى قاعدة البيانات
      final backupFile = File(backupPath);
      final dbFile = File(dbPath);
      
      if (!await backupFile.exists()) {
        throw Exception('Backup file not found: $backupPath');
      }

      await backupFile.copy(dbPath);

      // إعادة فتح قاعدة البيانات
      await _db.database;

      AppLogger.info('Backup restored successfully from: $backupPath');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Restore backup error', e, stackTrace);
      return false;
    }
  }

  /// الحصول على قائمة النسخ الاحتياطية
  Future<List<Map<String, dynamic>>> getBackups() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory(path.join(appDir.path, 'backups'));

      if (!await backupDir.exists()) {
        return [];
      }

      final files = backupDir.listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.db'))
          .toList();

      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      return files.map((file) {
        final stat = file.statSync();
        return {
          'path': file.path,
          'name': path.basename(file.path),
          'size': stat.size,
          'createdAt': stat.modified.millisecondsSinceEpoch,
        };
      }).toList();
    } catch (e) {
      AppLogger.error('Get backups error', e);
      return [];
    }
  }

  /// جدولة النسخ الاحتياطي التلقائي
  Future<void> scheduleAutomaticBackup({Duration interval = const Duration(hours: 24)}) async {
    // TODO: استخدام Timer أو WorkManager للنسخ التلقائي
    // يمكن تنفيذ هذا لاحقاً
  }
}

