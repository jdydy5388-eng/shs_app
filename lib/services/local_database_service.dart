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
  static const int _databaseVersion = 21;
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

    // جداول التمريض
    await db.execute('''
      CREATE TABLE IF NOT EXISTS nursing_tasks (
        id TEXT PRIMARY KEY,
        nurse_id TEXT NOT NULL,
        patient_id TEXT,
        patient_name TEXT,
        bed_id TEXT,
        room_id TEXT,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        status TEXT NOT NULL,
        scheduled_at INTEGER NOT NULL,
        completed_at INTEGER,
        completed_by TEXT,
        result_data TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS nursing_notes (
        id TEXT PRIMARY KEY,
        nurse_id TEXT NOT NULL,
        nurse_name TEXT,
        patient_id TEXT NOT NULL,
        patient_name TEXT,
        bed_id TEXT,
        room_id TEXT,
        note TEXT NOT NULL,
        vital_signs TEXT,
        observations TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER
      )
    ''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_nursing_tasks_nurse ON nursing_tasks(nurse_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_nursing_tasks_patient ON nursing_tasks(patient_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_nursing_tasks_status ON nursing_tasks(status)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_nursing_notes_nurse ON nursing_notes(nurse_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_nursing_notes_patient ON nursing_notes(patient_id)');

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

    // جدول العمليات الجراحية
    await db.execute('''
      CREATE TABLE IF NOT EXISTS surgeries (
        id TEXT PRIMARY KEY,
        patient_id TEXT NOT NULL,
        patient_name TEXT NOT NULL,
        surgery_name TEXT NOT NULL,
        type TEXT NOT NULL,
        status TEXT NOT NULL,
        scheduled_date INTEGER NOT NULL,
        start_time INTEGER,
        end_time INTEGER,
        operation_room_id TEXT,
        operation_room_name TEXT,
        surgeon_id TEXT NOT NULL,
        surgeon_name TEXT NOT NULL,
        assistant_surgeon_id TEXT,
        assistant_surgeon_name TEXT,
        anesthesiologist_id TEXT,
        anesthesiologist_name TEXT,
        nurse_ids TEXT,
        nurse_names TEXT,
        pre_operative_notes TEXT,
        operative_notes TEXT,
        post_operative_notes TEXT,
        diagnosis TEXT,
        procedure TEXT,
        notes TEXT,
        equipment TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER
      )
    ''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_surgeries_patient ON surgeries(patient_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_surgeries_surgeon ON surgeries(surgeon_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_surgeries_status ON surgeries(status)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_surgeries_date ON surgeries(scheduled_date)');

    // جدول المستودع الطبي العام
    await db.execute('''
      CREATE TABLE IF NOT EXISTS medical_inventory (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        category TEXT,
        description TEXT,
        quantity INTEGER NOT NULL DEFAULT 0,
        min_stock_level INTEGER,
        unit TEXT,
        unit_price REAL,
        manufacturer TEXT,
        model TEXT,
        serial_number TEXT,
        purchase_date INTEGER,
        expiry_date INTEGER,
        location TEXT,
        status TEXT,
        last_maintenance_date INTEGER,
        next_maintenance_date INTEGER,
        supplier_id TEXT,
        supplier_name TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER
      )
    ''');

    // جدول الموردين
    await db.execute('''
      CREATE TABLE IF NOT EXISTS suppliers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        contact_person TEXT,
        email TEXT,
        phone TEXT,
        address TEXT,
        notes TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER
      )
    ''');

    // جدول طلبات الشراء
    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_orders (
        id TEXT PRIMARY KEY,
        order_number TEXT NOT NULL UNIQUE,
        supplier_id TEXT,
        supplier_name TEXT,
        items TEXT NOT NULL,
        total_amount REAL NOT NULL,
        status TEXT NOT NULL,
        notes TEXT,
        requested_by TEXT,
        requested_date INTEGER,
        approved_by TEXT,
        approved_date INTEGER,
        ordered_date INTEGER,
        received_date INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER
      )
    ''');

    // جدول سجلات الصيانة
    await db.execute('''
      CREATE TABLE IF NOT EXISTS maintenance_records (
        id TEXT PRIMARY KEY,
        equipment_id TEXT NOT NULL,
        equipment_name TEXT NOT NULL,
        maintenance_date INTEGER NOT NULL,
        maintenance_type TEXT NOT NULL,
        description TEXT,
        performed_by TEXT,
        cost REAL,
        next_maintenance_date INTEGER,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_medical_inventory_type ON medical_inventory(type)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_medical_inventory_status ON medical_inventory(status)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_purchase_orders_status ON purchase_orders(status)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_maintenance_records_equipment ON maintenance_records(equipment_id)');

    // جدول الصيدلية الداخلية - جدول الأدوية
    await db.execute('''
      CREATE TABLE IF NOT EXISTS hospital_pharmacy_dispenses (
        id TEXT PRIMARY KEY,
        patient_id TEXT NOT NULL,
        patient_name TEXT NOT NULL,
        bed_id TEXT,
        room_id TEXT,
        prescription_id TEXT NOT NULL,
        medication_id TEXT NOT NULL,
        medication_name TEXT NOT NULL,
        dosage TEXT NOT NULL,
        frequency TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        status TEXT NOT NULL,
        schedule_type TEXT NOT NULL,
        scheduled_time INTEGER NOT NULL,
        dispensed_at INTEGER,
        dispensed_by TEXT,
        notes TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER
      )
    ''');

    // جدول جدولة الأدوية
    await db.execute('''
      CREATE TABLE IF NOT EXISTS medication_schedules (
        id TEXT PRIMARY KEY,
        patient_id TEXT NOT NULL,
        patient_name TEXT NOT NULL,
        bed_id TEXT,
        room_id TEXT,
        prescription_id TEXT NOT NULL,
        medication_id TEXT NOT NULL,
        medication_name TEXT NOT NULL,
        dosage TEXT NOT NULL,
        frequency TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        schedule_type TEXT NOT NULL,
        start_date INTEGER NOT NULL,
        end_date INTEGER,
        scheduled_times TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        notes TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER
      )
    ''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_dispenses_patient ON hospital_pharmacy_dispenses(patient_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_dispenses_status ON hospital_pharmacy_dispenses(status)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_dispenses_scheduled_time ON hospital_pharmacy_dispenses(scheduled_time)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_schedules_patient ON medication_schedules(patient_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_schedules_active ON medication_schedules(is_active)');

    // جدول أنواع الفحوصات المختبرية
    await db.execute('''
      CREATE TABLE IF NOT EXISTS lab_test_types (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        arabic_name TEXT,
        category TEXT NOT NULL,
        description TEXT,
        price REAL NOT NULL DEFAULT 0,
        estimated_duration_minutes INTEGER,
        default_priority TEXT NOT NULL DEFAULT 'routine',
        required_samples TEXT,
        normal_ranges TEXT,
        critical_values TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER
      )
    ''');

    // جدول عينات الفحوصات
    await db.execute('''
      CREATE TABLE IF NOT EXISTS lab_samples (
        id TEXT PRIMARY KEY,
        lab_request_id TEXT NOT NULL,
        type TEXT NOT NULL,
        status TEXT NOT NULL,
        collection_location TEXT,
        collected_at INTEGER,
        collected_by TEXT,
        received_at INTEGER,
        received_by TEXT,
        notes TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER
      )
    ''');

    // جدول نتائج الفحوصات
    await db.execute('''
      CREATE TABLE IF NOT EXISTS lab_results (
        id TEXT PRIMARY KEY,
        lab_request_id TEXT NOT NULL UNIQUE,
        results TEXT NOT NULL,
        interpretation TEXT,
        is_critical INTEGER NOT NULL DEFAULT 0,
        reviewed_by TEXT,
        reviewed_at INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER
      )
    ''');

    // جدول جدولة الفحوصات
    await db.execute('''
      CREATE TABLE IF NOT EXISTS lab_schedules (
        id TEXT PRIMARY KEY,
        lab_request_id TEXT NOT NULL,
        scheduled_date INTEGER NOT NULL,
        scheduled_time TEXT,
        priority TEXT NOT NULL DEFAULT 'routine',
        notes TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER
      )
    ''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_lab_test_types_category ON lab_test_types(category)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_lab_test_types_active ON lab_test_types(is_active)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_lab_samples_request ON lab_samples(lab_request_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_lab_results_request ON lab_results(lab_request_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_lab_schedules_date ON lab_schedules(scheduled_date)');
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
    
    if (oldVersion < 12) {
      // إضافة جداول التمريض
      await db.execute('''
        CREATE TABLE IF NOT EXISTS nursing_tasks (
          id TEXT PRIMARY KEY,
          nurse_id TEXT NOT NULL,
          patient_id TEXT,
          patient_name TEXT,
          bed_id TEXT,
          room_id TEXT,
          type TEXT NOT NULL,
          title TEXT NOT NULL,
          description TEXT,
          status TEXT NOT NULL,
          scheduled_at INTEGER NOT NULL,
          completed_at INTEGER,
          completed_by TEXT,
          result_data TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS nursing_notes (
          id TEXT PRIMARY KEY,
          nurse_id TEXT NOT NULL,
          nurse_name TEXT,
          patient_id TEXT NOT NULL,
          patient_name TEXT,
          bed_id TEXT,
          room_id TEXT,
          note TEXT NOT NULL,
          vital_signs TEXT,
          observations TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER
        )
      ''');

      await db.execute('CREATE INDEX IF NOT EXISTS idx_nursing_tasks_nurse ON nursing_tasks(nurse_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_nursing_tasks_patient ON nursing_tasks(patient_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_nursing_tasks_status ON nursing_tasks(status)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_nursing_notes_nurse ON nursing_notes(nurse_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_nursing_notes_patient ON nursing_notes(patient_id)');
      }
      if (oldVersion < 13) {
        // إضافة جدول العمليات الجراحية
        await db.execute('''
          CREATE TABLE IF NOT EXISTS surgeries (
            id TEXT PRIMARY KEY,
            patient_id TEXT NOT NULL,
            patient_name TEXT NOT NULL,
            surgery_name TEXT NOT NULL,
            type TEXT NOT NULL,
            status TEXT NOT NULL,
            scheduled_date INTEGER NOT NULL,
            start_time INTEGER,
            end_time INTEGER,
            operation_room_id TEXT,
            operation_room_name TEXT,
            surgeon_id TEXT NOT NULL,
            surgeon_name TEXT NOT NULL,
            assistant_surgeon_id TEXT,
            assistant_surgeon_name TEXT,
            anesthesiologist_id TEXT,
            anesthesiologist_name TEXT,
            nurse_ids TEXT,
            nurse_names TEXT,
            pre_operative_notes TEXT,
            operative_notes TEXT,
            post_operative_notes TEXT,
            diagnosis TEXT,
            procedure TEXT,
            notes TEXT,
            equipment TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER
          )
        ''');

        await db.execute('CREATE INDEX IF NOT EXISTS idx_surgeries_patient ON surgeries(patient_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_surgeries_surgeon ON surgeries(surgeon_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_surgeries_status ON surgeries(status)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_surgeries_date ON surgeries(scheduled_date)');
      }
      if (oldVersion < 14) {
        // إضافة جداول المستودع الطبي
        await db.execute('''
          CREATE TABLE IF NOT EXISTS medical_inventory (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            type TEXT NOT NULL,
            category TEXT,
            description TEXT,
            quantity INTEGER NOT NULL DEFAULT 0,
            min_stock_level INTEGER,
            unit TEXT,
            unit_price REAL,
            manufacturer TEXT,
            model TEXT,
            serial_number TEXT,
            purchase_date INTEGER,
            expiry_date INTEGER,
            location TEXT,
            status TEXT,
            last_maintenance_date INTEGER,
            next_maintenance_date INTEGER,
            supplier_id TEXT,
            supplier_name TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS suppliers (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            contact_person TEXT,
            email TEXT,
            phone TEXT,
            address TEXT,
            notes TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS purchase_orders (
            id TEXT PRIMARY KEY,
            order_number TEXT NOT NULL UNIQUE,
            supplier_id TEXT,
            supplier_name TEXT,
            items TEXT NOT NULL,
            total_amount REAL NOT NULL,
            status TEXT NOT NULL,
            notes TEXT,
            requested_by TEXT,
            requested_date INTEGER,
            approved_by TEXT,
            approved_date INTEGER,
            ordered_date INTEGER,
            received_date INTEGER,
            created_at INTEGER NOT NULL,
            updated_at INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS maintenance_records (
            id TEXT PRIMARY KEY,
            equipment_id TEXT NOT NULL,
            equipment_name TEXT NOT NULL,
            maintenance_date INTEGER NOT NULL,
            maintenance_type TEXT NOT NULL,
            description TEXT,
            performed_by TEXT,
            cost REAL,
            next_maintenance_date INTEGER,
            created_at INTEGER NOT NULL
          )
        ''');

        await db.execute('CREATE INDEX IF NOT EXISTS idx_medical_inventory_type ON medical_inventory(type)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_medical_inventory_status ON medical_inventory(status)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_purchase_orders_status ON purchase_orders(status)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_maintenance_records_equipment ON maintenance_records(equipment_id)');
      }
      if (oldVersion < 15) {
        // إضافة جداول الصيدلية الداخلية
        await db.execute('''
          CREATE TABLE IF NOT EXISTS hospital_pharmacy_dispenses (
            id TEXT PRIMARY KEY,
            patient_id TEXT NOT NULL,
            patient_name TEXT NOT NULL,
            bed_id TEXT,
            room_id TEXT,
            prescription_id TEXT NOT NULL,
            medication_id TEXT NOT NULL,
            medication_name TEXT NOT NULL,
            dosage TEXT NOT NULL,
            frequency TEXT NOT NULL,
            quantity INTEGER NOT NULL,
            status TEXT NOT NULL,
            schedule_type TEXT NOT NULL,
            scheduled_time INTEGER NOT NULL,
            dispensed_at INTEGER,
            dispensed_by TEXT,
            notes TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS medication_schedules (
            id TEXT PRIMARY KEY,
            patient_id TEXT NOT NULL,
            patient_name TEXT NOT NULL,
            bed_id TEXT,
            room_id TEXT,
            prescription_id TEXT NOT NULL,
            medication_id TEXT NOT NULL,
            medication_name TEXT NOT NULL,
            dosage TEXT NOT NULL,
            frequency TEXT NOT NULL,
            quantity INTEGER NOT NULL,
            schedule_type TEXT NOT NULL,
            start_date INTEGER NOT NULL,
            end_date INTEGER,
            scheduled_times TEXT NOT NULL,
            is_active INTEGER NOT NULL DEFAULT 1,
            notes TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER
          )
        ''');

        await db.execute('CREATE INDEX IF NOT EXISTS idx_dispenses_patient ON hospital_pharmacy_dispenses(patient_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_dispenses_status ON hospital_pharmacy_dispenses(status)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_dispenses_scheduled_time ON hospital_pharmacy_dispenses(scheduled_time)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_schedules_patient ON medication_schedules(patient_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_schedules_active ON medication_schedules(is_active)');
      }
      if (oldVersion < 16) {
        // إضافة جداول تحسينات المختبر
        await db.execute('''
          CREATE TABLE IF NOT EXISTS lab_test_types (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            arabic_name TEXT,
            category TEXT NOT NULL,
            description TEXT,
            price REAL NOT NULL DEFAULT 0,
            estimated_duration_minutes INTEGER,
            default_priority TEXT NOT NULL DEFAULT 'routine',
            required_samples TEXT,
            normal_ranges TEXT,
            critical_values TEXT,
            is_active INTEGER NOT NULL DEFAULT 1,
            created_at INTEGER NOT NULL,
            updated_at INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS lab_samples (
            id TEXT PRIMARY KEY,
            lab_request_id TEXT NOT NULL,
            type TEXT NOT NULL,
            status TEXT NOT NULL,
            collection_location TEXT,
            collected_at INTEGER,
            collected_by TEXT,
            received_at INTEGER,
            received_by TEXT,
            notes TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS lab_results (
            id TEXT PRIMARY KEY,
            lab_request_id TEXT NOT NULL UNIQUE,
            results TEXT NOT NULL,
            interpretation TEXT,
            is_critical INTEGER NOT NULL DEFAULT 0,
            reviewed_by TEXT,
            reviewed_at INTEGER,
            created_at INTEGER NOT NULL,
            updated_at INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS lab_schedules (
            id TEXT PRIMARY KEY,
            lab_request_id TEXT NOT NULL,
            scheduled_date INTEGER NOT NULL,
            scheduled_time TEXT,
            priority TEXT NOT NULL DEFAULT 'routine',
            notes TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER
          )
        ''');

        await db.execute('CREATE INDEX IF NOT EXISTS idx_lab_test_types_category ON lab_test_types(category)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_lab_test_types_active ON lab_test_types(is_active)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_lab_samples_request ON lab_samples(lab_request_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_lab_results_request ON lab_results(lab_request_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_lab_schedules_date ON lab_schedules(scheduled_date)');
      }
      if (oldVersion < 17) {
        // إضافة جداول إدارة الوثائق
        await db.execute('''
          CREATE TABLE IF NOT EXISTS documents (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            description TEXT,
            category TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'active',
            access_level TEXT NOT NULL DEFAULT 'private',
            patient_id TEXT,
            patient_name TEXT,
            doctor_id TEXT,
            doctor_name TEXT,
            shared_with_user_ids TEXT,
            tags TEXT,
            file_url TEXT NOT NULL,
            file_name TEXT NOT NULL,
            file_type TEXT,
            file_size INTEGER,
            thumbnail_url TEXT,
            metadata TEXT,
            signature_id TEXT,
            signed_at INTEGER,
            signed_by TEXT,
            archived_at INTEGER,
            archived_by TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER,
            created_by TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS document_signatures (
            id TEXT PRIMARY KEY,
            document_id TEXT NOT NULL,
            signed_by TEXT NOT NULL,
            signed_by_name TEXT NOT NULL,
            signature_data TEXT NOT NULL,
            signed_at INTEGER NOT NULL,
            notes TEXT
          )
        ''');

        await db.execute('CREATE INDEX IF NOT EXISTS idx_documents_category ON documents(category)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_documents_status ON documents(status)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_documents_patient ON documents(patient_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_documents_doctor ON documents(doctor_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_documents_created_by ON documents(created_by)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_signatures_document ON document_signatures(document_id)');

        // جداول نظام الجودة
        await db.execute('''
          CREATE TABLE IF NOT EXISTS quality_kpis (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            arabic_name TEXT,
            description TEXT NOT NULL,
            category TEXT NOT NULL,
            type TEXT NOT NULL,
            target_value REAL,
            current_value REAL,
            unit TEXT,
            last_updated INTEGER,
            updated_by TEXT,
            metadata TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS medical_incidents (
            id TEXT PRIMARY KEY,
            patient_id TEXT,
            patient_name TEXT,
            type TEXT NOT NULL,
            severity TEXT NOT NULL,
            status TEXT NOT NULL,
            description TEXT NOT NULL,
            location TEXT,
            incident_date INTEGER NOT NULL,
            reported_date INTEGER,
            reported_by TEXT,
            reported_by_name TEXT,
            investigation_notes TEXT,
            resolution_notes TEXT,
            resolved_by TEXT,
            resolved_at INTEGER,
            affected_persons TEXT,
            additional_data TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS complaints (
            id TEXT PRIMARY KEY,
            patient_id TEXT,
            patient_name TEXT,
            complainant_name TEXT,
            complainant_phone TEXT,
            complainant_email TEXT,
            category TEXT NOT NULL,
            status TEXT NOT NULL,
            subject TEXT NOT NULL,
            description TEXT NOT NULL,
            department TEXT,
            assigned_to TEXT,
            assigned_to_name TEXT,
            response TEXT,
            responded_by TEXT,
            responded_at INTEGER,
            complaint_date INTEGER NOT NULL,
            resolved_at INTEGER,
            additional_data TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS accreditation_requirements (
            id TEXT PRIMARY KEY,
            standard TEXT NOT NULL,
            requirement_code TEXT NOT NULL,
            title TEXT NOT NULL,
            description TEXT NOT NULL,
            status TEXT NOT NULL,
            evidence TEXT,
            notes TEXT,
            compliance_date INTEGER,
            certification_date INTEGER,
            assigned_to TEXT,
            assigned_to_name TEXT,
            due_date INTEGER,
            metadata TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER
          )
        ''');

        await db.execute('CREATE INDEX IF NOT EXISTS idx_kpis_category ON quality_kpis(category)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_incidents_type ON medical_incidents(type)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_incidents_severity ON medical_incidents(severity)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_incidents_status ON medical_incidents(status)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_complaints_category ON complaints(category)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_complaints_status ON complaints(status)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_accreditation_standard ON accreditation_requirements(standard)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_accreditation_status ON accreditation_requirements(status)');
      }

      if (oldVersion < 18) {
        // إضافة جداول نظام الجودة (تم إضافتها في _onCreate)
      }

      if (oldVersion < 19) {
        // إضافة جداول نظام الموارد البشرية
        await db.execute('''
          CREATE TABLE IF NOT EXISTS employees (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            employee_number TEXT NOT NULL UNIQUE,
            department TEXT NOT NULL,
            position TEXT NOT NULL,
            employment_type TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'active',
            hire_date INTEGER NOT NULL,
            termination_date INTEGER,
            salary REAL,
            manager_id TEXT,
            manager_name TEXT,
            additional_info TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS leave_requests (
            id TEXT PRIMARY KEY,
            employee_id TEXT NOT NULL,
            employee_name TEXT,
            type TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'pending',
            start_date INTEGER NOT NULL,
            end_date INTEGER NOT NULL,
            days INTEGER NOT NULL,
            reason TEXT,
            notes TEXT,
            approved_by TEXT,
            approved_by_name TEXT,
            approved_at INTEGER,
            rejection_reason TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS payrolls (
            id TEXT PRIMARY KEY,
            employee_id TEXT NOT NULL,
            employee_name TEXT,
            pay_period_start INTEGER NOT NULL,
            pay_period_end INTEGER NOT NULL,
            base_salary REAL NOT NULL,
            allowances REAL,
            deductions REAL,
            bonuses REAL,
            overtime REAL,
            net_salary REAL NOT NULL,
            status TEXT NOT NULL DEFAULT 'draft',
            paid_date INTEGER,
            notes TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS trainings (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            description TEXT,
            trainer TEXT,
            location TEXT,
            start_date INTEGER NOT NULL,
            end_date INTEGER NOT NULL,
            max_participants INTEGER,
            participant_ids TEXT,
            status TEXT NOT NULL DEFAULT 'scheduled',
            notes TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS certifications (
            id TEXT PRIMARY KEY,
            employee_id TEXT NOT NULL,
            employee_name TEXT,
            certificate_name TEXT NOT NULL,
            issuing_organization TEXT NOT NULL,
            issue_date INTEGER NOT NULL,
            expiry_date INTEGER NOT NULL,
            certificate_number TEXT,
            certificate_url TEXT,
            status TEXT NOT NULL DEFAULT 'active',
            notes TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER
          )
        ''');

        await db.execute('CREATE INDEX IF NOT EXISTS idx_employees_status ON employees(status)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_employees_department ON employees(department)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_leave_requests_employee ON leave_requests(employee_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_leave_requests_status ON leave_requests(status)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_payrolls_employee ON payrolls(employee_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_payrolls_status ON payrolls(status)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_certifications_employee ON certifications(employee_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_certifications_status ON certifications(status)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_certifications_expiry ON certifications(expiry_date)');
      }
        await db.execute('''
          CREATE TABLE IF NOT EXISTS quality_kpis (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            arabic_name TEXT,
            description TEXT NOT NULL,
            category TEXT NOT NULL,
            type TEXT NOT NULL,
            target_value REAL,
            current_value REAL,
            unit TEXT,
            last_updated INTEGER,
            updated_by TEXT,
            metadata TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS medical_incidents (
            id TEXT PRIMARY KEY,
            patient_id TEXT,
            patient_name TEXT,
            type TEXT NOT NULL,
            severity TEXT NOT NULL,
            status TEXT NOT NULL,
            description TEXT NOT NULL,
            location TEXT,
            incident_date INTEGER NOT NULL,
            reported_date INTEGER,
            reported_by TEXT,
            reported_by_name TEXT,
            investigation_notes TEXT,
            resolution_notes TEXT,
            resolved_by TEXT,
            resolved_at INTEGER,
            affected_persons TEXT,
            additional_data TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS complaints (
            id TEXT PRIMARY KEY,
            patient_id TEXT,
            patient_name TEXT,
            complainant_name TEXT,
            complainant_phone TEXT,
            complainant_email TEXT,
            category TEXT NOT NULL,
            status TEXT NOT NULL,
            subject TEXT NOT NULL,
            description TEXT NOT NULL,
            department TEXT,
            assigned_to TEXT,
            assigned_to_name TEXT,
            response TEXT,
            responded_by TEXT,
            responded_at INTEGER,
            complaint_date INTEGER NOT NULL,
            resolved_at INTEGER,
            additional_data TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS accreditation_requirements (
            id TEXT PRIMARY KEY,
            standard TEXT NOT NULL,
            requirement_code TEXT NOT NULL,
            title TEXT NOT NULL,
            description TEXT NOT NULL,
            status TEXT NOT NULL,
            evidence TEXT,
            notes TEXT,
            compliance_date INTEGER,
            certification_date INTEGER,
            assigned_to TEXT,
            assigned_to_name TEXT,
            due_date INTEGER,
            metadata TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER
          )
        ''');

        await db.execute('CREATE INDEX IF NOT EXISTS idx_kpis_category ON quality_kpis(category)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_incidents_type ON medical_incidents(type)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_incidents_severity ON medical_incidents(severity)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_incidents_status ON medical_incidents(status)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_complaints_category ON complaints(category)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_complaints_status ON complaints(status)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_accreditation_standard ON accreditation_requirements(standard)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_accreditation_status ON accreditation_requirements(status)');

        // جداول نظام الموارد البشرية
        await db.execute('''
          CREATE TABLE IF NOT EXISTS employees (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            employee_number TEXT NOT NULL UNIQUE,
            department TEXT NOT NULL,
            position TEXT NOT NULL,
            employment_type TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'active',
            hire_date INTEGER NOT NULL,
            termination_date INTEGER,
            salary REAL,
            manager_id TEXT,
            manager_name TEXT,
            additional_info TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS leave_requests (
            id TEXT PRIMARY KEY,
            employee_id TEXT NOT NULL,
            employee_name TEXT,
            type TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'pending',
            start_date INTEGER NOT NULL,
            end_date INTEGER NOT NULL,
            days INTEGER NOT NULL,
            reason TEXT,
            notes TEXT,
            approved_by TEXT,
            approved_by_name TEXT,
            approved_at INTEGER,
            rejection_reason TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS payrolls (
            id TEXT PRIMARY KEY,
            employee_id TEXT NOT NULL,
            employee_name TEXT,
            pay_period_start INTEGER NOT NULL,
            pay_period_end INTEGER NOT NULL,
            base_salary REAL NOT NULL,
            allowances REAL,
            deductions REAL,
            bonuses REAL,
            overtime REAL,
            net_salary REAL NOT NULL,
            status TEXT NOT NULL DEFAULT 'draft',
            paid_date INTEGER,
            notes TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS trainings (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            description TEXT,
            trainer TEXT,
            location TEXT,
            start_date INTEGER NOT NULL,
            end_date INTEGER NOT NULL,
            max_participants INTEGER,
            participant_ids TEXT,
            status TEXT NOT NULL DEFAULT 'scheduled',
            notes TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS certifications (
            id TEXT PRIMARY KEY,
            employee_id TEXT NOT NULL,
            employee_name TEXT,
            certificate_name TEXT NOT NULL,
            issuing_organization TEXT NOT NULL,
            issue_date INTEGER NOT NULL,
            expiry_date INTEGER NOT NULL,
            certificate_number TEXT,
            certificate_url TEXT,
            status TEXT NOT NULL DEFAULT 'active',
            notes TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER
          )
        ''');

        await db.execute('CREATE INDEX IF NOT EXISTS idx_employees_status ON employees(status)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_employees_department ON employees(department)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_leave_requests_employee ON leave_requests(employee_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_leave_requests_status ON leave_requests(status)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_payrolls_employee ON payrolls(employee_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_payrolls_status ON payrolls(status)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_certifications_employee ON certifications(employee_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_certifications_status ON certifications(status)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_certifications_expiry ON certifications(expiry_date)');

        // جداول نظام الصيانة
        await db.execute('''
          CREATE TABLE IF NOT EXISTS maintenance_requests (
            id TEXT PRIMARY KEY,
            equipment_id TEXT,
            equipment_name TEXT,
            location TEXT,
            type TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'pending',
            priority TEXT NOT NULL DEFAULT 'medium',
            description TEXT NOT NULL,
            reported_by TEXT,
            reported_by_name TEXT,
            reported_date INTEGER NOT NULL,
            assigned_to TEXT,
            assigned_to_name TEXT,
            assigned_date INTEGER,
            scheduled_date INTEGER,
            completed_date INTEGER,
            completed_by TEXT,
            completed_by_name TEXT,
            work_performed TEXT,
            notes TEXT,
            cost REAL,
            attachments TEXT,
            additional_data TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS scheduled_maintenances (
            id TEXT PRIMARY KEY,
            equipment_id TEXT NOT NULL,
            equipment_name TEXT,
            maintenance_type TEXT NOT NULL,
            description TEXT NOT NULL,
            frequency TEXT NOT NULL,
            interval_days INTEGER,
            next_due_date INTEGER NOT NULL,
            last_performed_date INTEGER,
            last_performed_by TEXT,
            status TEXT NOT NULL DEFAULT 'scheduled',
            assigned_to TEXT,
            assigned_to_name TEXT,
            notes TEXT,
            metadata TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS equipment_statuses (
            id TEXT PRIMARY KEY,
            equipment_id TEXT NOT NULL,
            equipment_name TEXT,
            condition TEXT NOT NULL,
            location TEXT,
            last_maintenance_date INTEGER NOT NULL,
            next_maintenance_date INTEGER,
            total_maintenance_count INTEGER,
            total_maintenance_cost REAL,
            current_issues TEXT,
            notes TEXT,
            status_data TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS maintenance_vendors (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            type TEXT NOT NULL,
            contact_person TEXT,
            email TEXT,
            phone TEXT,
            address TEXT,
            specialization TEXT,
            notes TEXT,
            is_active INTEGER NOT NULL DEFAULT 1,
            additional_info TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER
          )
        ''');

        await db.execute('CREATE INDEX IF NOT EXISTS idx_maintenance_requests_status ON maintenance_requests(status)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_maintenance_requests_priority ON maintenance_requests(priority)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_scheduled_maintenances_due_date ON scheduled_maintenances(next_due_date)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_equipment_statuses_condition ON equipment_statuses(condition)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_maintenance_vendors_type ON maintenance_vendors(type)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_maintenance_vendors_active ON maintenance_vendors(is_active)');
      }

      if (oldVersion < 20) {
        // إضافة جداول نظام الصيانة
        await db.execute('''
          CREATE TABLE IF NOT EXISTS maintenance_requests (
            id TEXT PRIMARY KEY,
            equipment_id TEXT,
            equipment_name TEXT,
            location TEXT,
            type TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'pending',
            priority TEXT NOT NULL DEFAULT 'medium',
            description TEXT NOT NULL,
            reported_by TEXT,
            reported_by_name TEXT,
            reported_date INTEGER NOT NULL,
            assigned_to TEXT,
            assigned_to_name TEXT,
            assigned_date INTEGER,
            scheduled_date INTEGER,
            completed_date INTEGER,
            completed_by TEXT,
            completed_by_name TEXT,
            work_performed TEXT,
            notes TEXT,
            cost REAL,
            attachments TEXT,
            additional_data TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS scheduled_maintenances (
            id TEXT PRIMARY KEY,
            equipment_id TEXT NOT NULL,
            equipment_name TEXT,
            maintenance_type TEXT NOT NULL,
            description TEXT NOT NULL,
            frequency TEXT NOT NULL,
            interval_days INTEGER,
            next_due_date INTEGER NOT NULL,
            last_performed_date INTEGER,
            last_performed_by TEXT,
            status TEXT NOT NULL DEFAULT 'scheduled',
            assigned_to TEXT,
            assigned_to_name TEXT,
            notes TEXT,
            metadata TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS equipment_statuses (
            id TEXT PRIMARY KEY,
            equipment_id TEXT NOT NULL,
            equipment_name TEXT,
            condition TEXT NOT NULL,
            location TEXT,
            last_maintenance_date INTEGER NOT NULL,
            next_maintenance_date INTEGER,
            total_maintenance_count INTEGER,
            total_maintenance_cost REAL,
            current_issues TEXT,
            notes TEXT,
            status_data TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS maintenance_vendors (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            type TEXT NOT NULL,
            contact_person TEXT,
            email TEXT,
            phone TEXT,
            address TEXT,
            specialization TEXT,
            notes TEXT,
            is_active INTEGER NOT NULL DEFAULT 1,
            additional_info TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER
          )
        ''');

        await db.execute('CREATE INDEX IF NOT EXISTS idx_maintenance_requests_status ON maintenance_requests(status)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_maintenance_requests_priority ON maintenance_requests(priority)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_scheduled_maintenances_due_date ON scheduled_maintenances(next_due_date)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_equipment_statuses_condition ON equipment_statuses(condition)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_maintenance_vendors_type ON maintenance_vendors(type)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_maintenance_vendors_active ON maintenance_vendors(is_active)');
      }

      if (oldVersion < 21) {
        // إضافة جداول نظام المواصلات
        await db.execute('''
          CREATE TABLE IF NOT EXISTS ambulances (
            id TEXT PRIMARY KEY,
            vehicle_number TEXT NOT NULL UNIQUE,
            vehicle_model TEXT,
            type TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'available',
            driver_id TEXT,
            driver_name TEXT,
            location TEXT,
            latitude REAL,
            longitude REAL,
            last_location_update INTEGER,
            equipment TEXT,
            notes TEXT,
            additional_info TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS transportation_requests (
            id TEXT PRIMARY KEY,
            patient_id TEXT,
            patient_name TEXT,
            type TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'pending',
            pickup_location TEXT,
            pickup_latitude REAL,
            pickup_longitude REAL,
            dropoff_location TEXT,
            dropoff_latitude REAL,
            dropoff_longitude REAL,
            requested_date INTEGER NOT NULL,
            scheduled_date INTEGER,
            pickup_time INTEGER,
            dropoff_time INTEGER,
            ambulance_id TEXT,
            ambulance_number TEXT,
            driver_id TEXT,
            driver_name TEXT,
            reason TEXT,
            notes TEXT,
            requested_by TEXT,
            requested_by_name TEXT,
            additional_data TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS location_tracking (
            id TEXT PRIMARY KEY,
            ambulance_id TEXT NOT NULL,
            ambulance_number TEXT,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            address TEXT,
            speed REAL,
            heading REAL,
            timestamp INTEGER NOT NULL,
            metadata TEXT
          )
        ''');

        await db.execute('CREATE INDEX IF NOT EXISTS idx_ambulances_status ON ambulances(status)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_ambulances_type ON ambulances(type)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_transportation_requests_status ON transportation_requests(status)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_transportation_requests_patient ON transportation_requests(patient_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_location_tracking_ambulance ON location_tracking(ambulance_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_location_tracking_timestamp ON location_tracking(timestamp)');
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

