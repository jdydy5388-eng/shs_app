import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// ignore: avoid_web_libraries_in_flutter
import 'dart:io' show Platform;

/// خدمة قاعدة البيانات المحلية باستخدام SQLite
class LocalDatabaseService {
  static Database? _database;
  static const String _databaseName = 'shs_app.db';
  static const int _databaseVersion = 11;
  static bool _initialized = false;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // على الويب، لا يمكننا استخدام SQLite
    if (kIsWeb) {
      throw UnsupportedError('LocalDatabaseService is not supported on web');
    }
    
    // تهيئة sqflite_common_ffi للـ Windows/Desktop
    if (!_initialized) {
      try {
        // التحقق من المنصة فقط إذا لم نكن على الويب
        if (!kIsWeb) {
          try {
            // ignore: undefined_class, undefined_getter
            final isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
            if (isDesktop) {
              sqfliteFfiInit();
              databaseFactory = databaseFactoryFfi;
            }
          } catch (e) {
            // تجاهل خطأ Platform على الويب
          }
        }
      } catch (e) {
        // تجاهل خطأ Platform
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

    // غرف وأسِرّة
    await db.execute('''
      CREATE TABLE IF NOT EXISTS rooms (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        floor INTEGER,
        notes TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS beds (
        id TEXT PRIMARY KEY,
        room_id TEXT NOT NULL,
        label TEXT NOT NULL,
        status TEXT NOT NULL,
        patient_id TEXT,
        occupied_since INTEGER,
        updated_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS bed_transfers (
        id TEXT PRIMARY KEY,
        patient_id TEXT NOT NULL,
        from_bed_id TEXT,
        to_bed_id TEXT NOT NULL,
        reason TEXT,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_beds_room ON beds(room_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_beds_status ON beds(status)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_bed_transfers_patient ON bed_transfers(patient_id)');

    // قسم الطوارئ
    await db.execute('''
      CREATE TABLE IF NOT EXISTS emergency_cases (
        id TEXT PRIMARY KEY,
        patient_id TEXT,
        patient_name TEXT,
        triage_level TEXT NOT NULL,
        status TEXT NOT NULL,
        vital_signs TEXT,
        symptoms TEXT,
        notes TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS emergency_events (
        id TEXT PRIMARY KEY,
        case_id TEXT NOT NULL,
        event_type TEXT NOT NULL,
        details TEXT,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_emergency_cases_status ON emergency_cases(status)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_emergency_cases_triage ON emergency_cases(triage_level)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_emergency_events_case ON emergency_events(case_id)');

    // جدول الإشعارات
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notifications (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        recipient TEXT NOT NULL,
        subject TEXT,
        message TEXT NOT NULL,
        scheduled_at INTEGER NOT NULL,
        status TEXT NOT NULL,
        related_type TEXT,
        related_id TEXT,
        created_at INTEGER NOT NULL,
        sent_at INTEGER,
        error TEXT
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_notifications_status ON notifications(status)');

    // الأشعة
    await db.execute('''
      CREATE TABLE IF NOT EXISTS radiology_requests (
        id TEXT PRIMARY KEY,
        doctor_id TEXT NOT NULL,
        patient_id TEXT NOT NULL,
        patient_name TEXT NOT NULL,
        modality TEXT NOT NULL,
        body_part TEXT,
        status TEXT NOT NULL,
        notes TEXT,
        requested_at INTEGER NOT NULL,
        scheduled_at INTEGER,
        completed_at INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS radiology_reports (
        id TEXT PRIMARY KEY,
        request_id TEXT NOT NULL,
        findings TEXT,
        impression TEXT,
        attachments TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_radiology_requests_patient ON radiology_requests(patient_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_radiology_requests_status ON radiology_requests(status)');

    // الحضور والمناوبات
    await db.execute('''
      CREATE TABLE IF NOT EXISTS attendance_records (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        role TEXT NOT NULL,
        check_in INTEGER NOT NULL,
        check_out INTEGER,
        location_lat REAL,
        location_lng REAL,
        notes TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS shifts (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        role TEXT NOT NULL,
        start_time INTEGER NOT NULL,
        end_time INTEGER NOT NULL,
        department TEXT,
        recurrence TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_attendance_user ON attendance_records(user_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_shifts_user ON shifts(user_id)');
    // جداول الفوترة
    await db.execute('''
      CREATE TABLE IF NOT EXISTS invoices (
        id TEXT PRIMARY KEY,
        patient_id TEXT NOT NULL,
        patient_name TEXT NOT NULL,
        related_type TEXT,
        related_id TEXT,
        items TEXT NOT NULL,            -- JSON
        subtotal REAL NOT NULL,
        discount REAL NOT NULL DEFAULT 0,
        tax REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL,
        currency TEXT NOT NULL DEFAULT 'SAR',
        status TEXT NOT NULL,
        insurance_provider TEXT,
        insurance_policy TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER,
        paid_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS payments (
        id TEXT PRIMARY KEY,
        invoice_id TEXT NOT NULL,
        amount REAL NOT NULL,
        method TEXT NOT NULL,
        reference TEXT,
        created_at INTEGER NOT NULL,
        notes TEXT
      )
    ''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_invoices_patient ON invoices(patient_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_invoices_status ON invoices(status)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_payments_invoice ON payments(invoice_id)');
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
    if (oldVersion < 6) {
      // إنشاء جداول الفوترة
      await db.execute('''
        CREATE TABLE IF NOT EXISTS invoices (
          id TEXT PRIMARY KEY,
          patient_id TEXT NOT NULL,
          patient_name TEXT NOT NULL,
          related_type TEXT,
          related_id TEXT,
          items TEXT NOT NULL,
          subtotal REAL NOT NULL,
          discount REAL NOT NULL DEFAULT 0,
          tax REAL NOT NULL DEFAULT 0,
          total REAL NOT NULL,
          currency TEXT NOT NULL DEFAULT 'SAR',
          status TEXT NOT NULL,
          insurance_provider TEXT,
          insurance_policy TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER,
          paid_at INTEGER
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS payments (
          id TEXT PRIMARY KEY,
          invoice_id TEXT NOT NULL,
          amount REAL NOT NULL,
          method TEXT NOT NULL,
          reference TEXT,
          created_at INTEGER NOT NULL,
          notes TEXT
        )
      ''');

      await db.execute('CREATE INDEX IF NOT EXISTS idx_invoices_patient ON invoices(patient_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_invoices_status ON invoices(status)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_payments_invoice ON payments(invoice_id)');
    }
    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS rooms (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          type TEXT NOT NULL,
          floor INTEGER,
          notes TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS beds (
          id TEXT PRIMARY KEY,
          room_id TEXT NOT NULL,
          label TEXT NOT NULL,
          status TEXT NOT NULL,
          patient_id TEXT,
          occupied_since INTEGER,
          updated_at INTEGER
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS bed_transfers (
          id TEXT PRIMARY KEY,
          patient_id TEXT NOT NULL,
          from_bed_id TEXT,
          to_bed_id TEXT NOT NULL,
          reason TEXT,
          created_at INTEGER NOT NULL
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_beds_room ON beds(room_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_beds_status ON beds(status)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_bed_transfers_patient ON bed_transfers(patient_id)');
    }
    if (oldVersion < 8) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS emergency_cases (
          id TEXT PRIMARY KEY,
          patient_id TEXT,
          patient_name TEXT,
          triage_level TEXT NOT NULL,
          status TEXT NOT NULL,
          vital_signs TEXT,
          symptoms TEXT,
          notes TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS emergency_events (
          id TEXT PRIMARY KEY,
          case_id TEXT NOT NULL,
          event_type TEXT NOT NULL,
          details TEXT,
          created_at INTEGER NOT NULL
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_emergency_cases_status ON emergency_cases(status)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_emergency_cases_triage ON emergency_cases(triage_level)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_emergency_events_case ON emergency_events(case_id)');
    }
    if (oldVersion < 9) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS notifications (
          id TEXT PRIMARY KEY,
          type TEXT NOT NULL,
          recipient TEXT NOT NULL,
          subject TEXT,
          message TEXT NOT NULL,
          scheduled_at INTEGER NOT NULL,
          status TEXT NOT NULL,
          related_type TEXT,
          related_id TEXT,
          created_at INTEGER NOT NULL,
          sent_at INTEGER,
          error TEXT
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_notifications_status ON notifications(status)');
    }
    if (oldVersion < 10) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS radiology_requests (
          id TEXT PRIMARY KEY,
          doctor_id TEXT NOT NULL,
          patient_id TEXT NOT NULL,
          patient_name TEXT NOT NULL,
          modality TEXT NOT NULL,
          body_part TEXT,
          status TEXT NOT NULL,
          notes TEXT,
          requested_at INTEGER NOT NULL,
          scheduled_at INTEGER,
          completed_at INTEGER
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS radiology_reports (
          id TEXT PRIMARY KEY,
          request_id TEXT NOT NULL,
          findings TEXT,
          impression TEXT,
          attachments TEXT,
          created_at INTEGER NOT NULL
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_radiology_requests_patient ON radiology_requests(patient_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_radiology_requests_status ON radiology_requests(status)');
    }
    if (oldVersion < 11) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS attendance_records (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          role TEXT NOT NULL,
          check_in INTEGER NOT NULL,
          check_out INTEGER,
          location_lat REAL,
          location_lng REAL,
          notes TEXT,
          created_at INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS shifts (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          role TEXT NOT NULL,
          start_time INTEGER NOT NULL,
          end_time INTEGER NOT NULL,
          department TEXT,
          recurrence TEXT,
          created_at INTEGER NOT NULL
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_attendance_user ON attendance_records(user_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_shifts_user ON shifts(user_id)');
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

