import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// خدمة قاعدة البيانات المحلية باستخدام SQLite
class LocalDatabaseService {
  static Database? _database;
  static const String _databaseName = 'shs_app.db';
  static const int _databaseVersion = 5;
  static bool _initialized = false;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // تهيئة sqflite_common_ffi للـ Windows/Desktop
    if (!_initialized) {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }
      _initialized = true;
    }

    // الحصول على مسار قاعدة البيانات
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // جدول المستخدمين
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        phone TEXT NOT NULL,
        role TEXT NOT NULL,
        profile_image_url TEXT,
        additional_info TEXT,
        created_at INTEGER NOT NULL,
        last_login_at INTEGER
      )
    ''');

    // جدول الوصفات الطبية
    await db.execute('''
      CREATE TABLE prescriptions (
        id TEXT PRIMARY KEY,
        doctor_id TEXT NOT NULL,
        doctor_name TEXT NOT NULL,
        patient_id TEXT NOT NULL,
        patient_name TEXT NOT NULL,
        diagnosis TEXT NOT NULL,
        notes TEXT,
        status TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        expires_at INTEGER
      )
    ''');

    // جدول الأدوية في الوصفات
    await db.execute('''
      CREATE TABLE prescription_medications (
        id TEXT PRIMARY KEY,
        prescription_id TEXT NOT NULL,
        name TEXT NOT NULL,
        dosage TEXT NOT NULL,
        frequency TEXT NOT NULL,
        duration TEXT NOT NULL,
        instructions TEXT,
        quantity INTEGER NOT NULL,
        FOREIGN KEY (prescription_id) REFERENCES prescriptions(id) ON DELETE CASCADE
      )
    ''');

    // جدول التفاعلات الدوائية
    await db.execute('''
      CREATE TABLE prescription_drug_interactions (
        prescription_id TEXT NOT NULL,
        interaction TEXT NOT NULL,
        PRIMARY KEY (prescription_id, interaction),
        FOREIGN KEY (prescription_id) REFERENCES prescriptions(id) ON DELETE CASCADE
      )
    ''');

    // جدول السجلات الطبية
    await db.execute('''
      CREATE TABLE medical_records (
        id TEXT PRIMARY KEY,
        patient_id TEXT NOT NULL,
        doctor_id TEXT,
        doctor_name TEXT,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        date INTEGER NOT NULL,
        file_urls TEXT,
        additional_data TEXT,
        created_at INTEGER NOT NULL
      )
    ''');

    // جدول الطلبات
    await db.execute('''
      CREATE TABLE orders (
        id TEXT PRIMARY KEY,
        patient_id TEXT NOT NULL,
        patient_name TEXT NOT NULL,
        pharmacy_id TEXT NOT NULL,
        pharmacy_name TEXT NOT NULL,
        prescription_id TEXT,
        status TEXT NOT NULL,
        total_amount REAL NOT NULL,
        delivery_address TEXT,
        notes TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER,
        delivered_at INTEGER
      )
    ''');

    // جدول عناصر الطلب
    await db.execute('''
      CREATE TABLE order_items (
        id TEXT PRIMARY KEY,
        order_id TEXT NOT NULL,
        medication_id TEXT NOT NULL,
        medication_name TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        price REAL NOT NULL,
        alternative_medication_id TEXT,
        alternative_medication_name TEXT,
        alternative_price REAL,
        FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
      )
    ''');

    // جدول المخزون
    await db.execute('''
      CREATE TABLE inventory (
        id TEXT PRIMARY KEY,
        pharmacy_id TEXT NOT NULL,
        medication_name TEXT NOT NULL,
        medication_id TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        price REAL NOT NULL,
        manufacturer TEXT,
        expiry_date INTEGER,
        batch_number TEXT,
        last_updated INTEGER NOT NULL
      )
    ''');

    await _createDoctorTables(db);
    await _createAdminTables(db);

    // إنشاء الفهارس
    await db.execute('CREATE INDEX idx_prescriptions_patient ON prescriptions(patient_id)');
    await db.execute('CREATE INDEX idx_prescriptions_doctor ON prescriptions(doctor_id)');
    await db.execute('CREATE INDEX idx_medical_records_patient ON medical_records(patient_id)');
    await db.execute('CREATE INDEX idx_orders_patient ON orders(patient_id)');
    await db.execute('CREATE INDEX idx_orders_pharmacy ON orders(pharmacy_id)');
    await db.execute('CREATE INDEX idx_inventory_pharmacy ON inventory(pharmacy_id)');
    await _createDoctorIndexes(db);
    await _createAdminIndexes(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createDoctorTables(db);
      await _createDoctorIndexes(db);
    }
    if (oldVersion < 3) {
      await _createAdminTables(db);
      await _createAdminIndexes(db);
    }
    if (oldVersion < 4) {
      // إضافة جدول إعدادات النظام
      await db.execute('''
        CREATE TABLE IF NOT EXISTS system_settings (
          id TEXT PRIMARY KEY,
          key TEXT UNIQUE NOT NULL,
          value TEXT NOT NULL,
          description TEXT NOT NULL,
          updated_at INTEGER NOT NULL,
          updated_by TEXT
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_system_settings_key ON system_settings(key)',
      );
      
      // إدراج الإعدادات الافتراضية
      final defaultSettings = [
        {
          'id': 'biometric_enabled',
          'key': 'biometric_enabled',
          'value': 'false',
          'description': 'تفعيل المصادقة البيومترية للنظام',
          'updated_at': DateTime.now().millisecondsSinceEpoch,
          'updated_by': null,
        },
      ];

      for (final setting in defaultSettings) {
        await db.insert(
          'system_settings',
          setting,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }

    if (oldVersion < 5) {
      try {
        await db.execute(
          'ALTER TABLE order_items ADD COLUMN alternative_medication_name TEXT',
        );
      } catch (_) {}
      try {
        await db.execute(
          'ALTER TABLE order_items ADD COLUMN alternative_price REAL',
        );
      } catch (_) {}
    }
  }

  Future<void> _createDoctorTables(Database db) async {
    // جدول مواعيد الطبيب
    await db.execute('''
      CREATE TABLE IF NOT EXISTS doctor_appointments (
        id TEXT PRIMARY KEY,
        doctor_id TEXT NOT NULL,
        patient_id TEXT,
        patient_name TEXT,
        date INTEGER NOT NULL,
        status TEXT NOT NULL,
        type TEXT,
        notes TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER
      )
    ''');

    // جدول مهام الطبيب
    await db.execute('''
      CREATE TABLE IF NOT EXISTS doctor_tasks (
        id TEXT PRIMARY KEY,
        doctor_id TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        due_date INTEGER,
        is_completed INTEGER NOT NULL,
        completed_at INTEGER,
        created_at INTEGER NOT NULL
      )
    ''');

    // جدول طلبات الفحوصات والتحاليل
    await db.execute('''
      CREATE TABLE IF NOT EXISTS lab_requests (
        id TEXT PRIMARY KEY,
        doctor_id TEXT NOT NULL,
        patient_id TEXT NOT NULL,
        patient_name TEXT NOT NULL,
        test_type TEXT NOT NULL,
        status TEXT NOT NULL,
        notes TEXT,
        result_notes TEXT,
        attachments TEXT,
        requested_at INTEGER NOT NULL,
        completed_at INTEGER
      )
    ''');
  }

  Future<void> _createDoctorIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_doctor_appointments_doctor ON doctor_appointments(doctor_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_doctor_tasks_doctor ON doctor_tasks(doctor_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_lab_requests_doctor ON lab_requests(doctor_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_lab_requests_patient ON lab_requests(patient_id)',
    );
  }

  Future<void> _createAdminTables(Database db) async {
    // جدول الكيانات المتعاقدة
    await db.execute('''
      CREATE TABLE IF NOT EXISTS entities (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        address TEXT NOT NULL,
        phone TEXT NOT NULL,
        email TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        license_number TEXT,
        notes TEXT,
        created_at INTEGER NOT NULL
      )
    ''');

    // جدول سجلات التدقيق
    await db.execute('''
      CREATE TABLE IF NOT EXISTS audit_logs (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        user_name TEXT NOT NULL,
        action TEXT NOT NULL,
        resource_type TEXT NOT NULL,
        resource_id TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        details TEXT,
        ip_address TEXT
      )
    ''');

    // جدول إعدادات النظام
    await db.execute('''
      CREATE TABLE IF NOT EXISTS system_settings (
        id TEXT PRIMARY KEY,
        key TEXT UNIQUE NOT NULL,
        value TEXT NOT NULL,
        description TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        updated_by TEXT
      )
    ''');

    // إدراج الإعدادات الافتراضية
    final defaultSettings = [
      {
        'id': 'biometric_enabled',
        'key': 'biometric_enabled',
        'value': 'false',
        'description': 'تفعيل المصادقة البيومترية للنظام',
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'updated_by': null,
      },
    ];

    for (final setting in defaultSettings) {
      await db.insert(
        'system_settings',
        setting,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<void> _createAdminIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_entities_type ON entities(type)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_audit_logs_user ON audit_logs(user_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_audit_logs_timestamp ON audit_logs(timestamp)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_system_settings_key ON system_settings(key)',
    );
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('users');
    await db.delete('prescriptions');
    await db.delete('prescription_medications');
    await db.delete('prescription_drug_interactions');
    await db.delete('medical_records');
    await db.delete('orders');
    await db.delete('order_items');
    await db.delete('inventory');
    await db.delete('doctor_appointments');
    await db.delete('doctor_tasks');
    await db.delete('lab_requests');
    await db.delete('entities');
    await db.delete('audit_logs');
    await db.delete('system_settings');
  }
}

