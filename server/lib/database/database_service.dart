import 'package:postgres/postgres.dart';
import 'dart:io';
import '../config/database_config.dart';
import '../logger/app_logger.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  PostgreSQLConnection? _connection;
  final _config = DatabaseConfig();

  Future<PostgreSQLConnection> get connection async {
    if (_connection != null) {
      return _connection!;
    }
    return await _connect();
  }

  Future<PostgreSQLConnection> _connect() async {
    try {
      _config.load();
      print('   Host: ${_config.host}:${_config.port}');
      print('   Database: ${_config.database}');
      print('   User: ${_config.user}');
      
      _connection = PostgreSQLConnection(
        _config.host,
        _config.port,
        _config.database,
        username: _config.user,
        password: _config.password,
        useSSL: _config.useSSL,
      );

      await _connection!.open();
      AppLogger.info('Connected to database: ${_config.database}');
      
      // إنشاء الجداول إذا لم تكن موجودة
      print('📊 Creating/verifying database tables...');
      await _createTables();
      
      return _connection!;
    } catch (e, stackTrace) {
      AppLogger.error('Database connection error: $e', stackTrace);
      // طباعة الخطأ مباشرة إلى stderr لتسهيل التشخيص
      stderr.writeln('');
      stderr.writeln('❌ Database connection failed!');
      stderr.writeln('Error: ${e.toString()}');
      stderr.writeln('');
      stderr.writeln('Please check:');
      stderr.writeln('  1. PostgreSQL is running');
      stderr.writeln('  2. Database credentials in .env file are correct');
      stderr.writeln('  3. Database "${_config.database}" exists');
      stderr.writeln('');
      rethrow;
    }
  }

  Future<void> _createTables() async {
    final conn = await connection;
    
    // جدول المستخدمين
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        phone TEXT NOT NULL,
        role TEXT NOT NULL,
        profile_image_url TEXT,
        additional_info JSONB,
        password_hash TEXT NOT NULL,
        created_at BIGINT NOT NULL,
        last_login_at BIGINT
      )
    ''');

    // جدول الوصفات الطبية
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS prescriptions (
        id TEXT PRIMARY KEY,
        doctor_id TEXT NOT NULL,
        doctor_name TEXT NOT NULL,
        patient_id TEXT NOT NULL,
        patient_name TEXT NOT NULL,
        diagnosis TEXT NOT NULL,
        notes TEXT,
        status TEXT NOT NULL,
        created_at BIGINT NOT NULL,
        expires_at BIGINT
      )
    ''');

    // جدول الأدوية في الوصفات
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS prescription_medications (
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
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS prescription_drug_interactions (
        prescription_id TEXT NOT NULL,
        interaction TEXT NOT NULL,
        PRIMARY KEY (prescription_id, interaction),
        FOREIGN KEY (prescription_id) REFERENCES prescriptions(id) ON DELETE CASCADE
      )
    ''');

    // جدول السجلات الطبية
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS medical_records (
        id TEXT PRIMARY KEY,
        patient_id TEXT NOT NULL,
        doctor_id TEXT,
        doctor_name TEXT,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        date BIGINT NOT NULL,
        file_urls JSONB,
        additional_data JSONB,
        created_at BIGINT NOT NULL
      )
    ''');

    // جدول الطلبات
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS orders (
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
        created_at BIGINT NOT NULL,
        updated_at BIGINT,
        delivered_at BIGINT
      )
    ''');

    // جدول عناصر الطلب
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS order_items (
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
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS inventory (
        id TEXT PRIMARY KEY,
        pharmacy_id TEXT NOT NULL,
        medication_name TEXT NOT NULL,
        medication_id TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        price REAL NOT NULL,
        manufacturer TEXT,
        expiry_date BIGINT,
        batch_number TEXT,
        last_updated BIGINT NOT NULL
      )
    ''');

    // جدول مواعيد الأطباء
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS doctor_appointments (
        id TEXT PRIMARY KEY,
        doctor_id TEXT NOT NULL,
        patient_id TEXT,
        patient_name TEXT,
        date BIGINT NOT NULL,
        status TEXT NOT NULL,
        type TEXT,
        notes TEXT,
        created_at BIGINT NOT NULL,
        updated_at BIGINT
      )
    ''');

    // جدول مهام الأطباء
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS doctor_tasks (
        id TEXT PRIMARY KEY,
        doctor_id TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        due_date BIGINT,
        is_completed BOOLEAN NOT NULL DEFAULT FALSE,
        created_at BIGINT NOT NULL
      )
    ''');

    // جدول طلبات الفحوصات
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS lab_requests (
        id TEXT PRIMARY KEY,
        doctor_id TEXT NOT NULL,
        patient_id TEXT NOT NULL,
        patient_name TEXT NOT NULL,
        test_type TEXT NOT NULL,
        status TEXT NOT NULL,
        notes TEXT,
        result_notes TEXT,
        result_attachments JSONB,
        requested_at BIGINT NOT NULL,
        completed_at BIGINT
      )
    ''');

    // جدول الكيانات (الصيدليات والمستشفيات)
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS entities (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        address TEXT,
        phone TEXT,
        email TEXT,
        location_lat REAL,
        location_lng REAL,
        created_at BIGINT NOT NULL,
        updated_at BIGINT
      )
    ''');

    // قسم الطوارئ - الحالات والأحداث
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS emergency_cases (
        id TEXT PRIMARY KEY,
        patient_id TEXT,
        patient_name TEXT,
        triage_level TEXT NOT NULL,        -- red / orange / yellow / green / blue
        status TEXT NOT NULL,              -- waiting / in_treatment / stabilized / transferred / discharged
        vital_signs JSONB,                 -- {hr, bp, rr, spo2, temp}
        symptoms TEXT,
        notes TEXT,
        created_at BIGINT NOT NULL,
        updated_at BIGINT
      )
    ''');

    await conn.execute('''
      CREATE TABLE IF NOT EXISTS emergency_events (
        id TEXT PRIMARY KEY,
        case_id TEXT NOT NULL,
        event_type TEXT NOT NULL,          -- intake / update_vitals / medication / imaging / transfer / discharge
        details JSONB,
        created_at BIGINT NOT NULL,
        FOREIGN KEY (case_id) REFERENCES emergency_cases(id) ON DELETE CASCADE
      )
    ''');

    // قسم الأشعة: طلبات وتقارير
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS radiology_requests (
        id TEXT PRIMARY KEY,
        doctor_id TEXT NOT NULL,
        patient_id TEXT NOT NULL,
        patient_name TEXT NOT NULL,
        modality TEXT NOT NULL,            -- xray / mri / ct / us / other
        body_part TEXT,
        status TEXT NOT NULL,              -- requested / scheduled / completed / cancelled
        notes TEXT,
        requested_at BIGINT NOT NULL,
        scheduled_at BIGINT,
        completed_at BIGINT
      )
    ''');

    await conn.execute('''
      CREATE TABLE IF NOT EXISTS radiology_reports (
        id TEXT PRIMARY KEY,
        request_id TEXT NOT NULL,
        findings TEXT,
        impression TEXT,
        attachments JSONB,                 -- image/report URLs
        created_at BIGINT NOT NULL,
        FOREIGN KEY (request_id) REFERENCES radiology_requests(id) ON DELETE CASCADE
      )
    ''');

    // الحضور والمناوبات
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS attendance_records (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        role TEXT NOT NULL,
        check_in BIGINT NOT NULL,
        check_out BIGINT,
        location_lat REAL,
        location_lng REAL,
        notes TEXT,
        created_at BIGINT NOT NULL
      )
    ''');

    await conn.execute('''
      CREATE TABLE IF NOT EXISTS shifts (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        role TEXT NOT NULL,
        start_time BIGINT NOT NULL,
        end_time BIGINT NOT NULL,
        department TEXT,
        recurrence TEXT,         -- none/daily/weekly
        created_at BIGINT NOT NULL
      )
    ''');
    // جدول سجلات التدقيق
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS audit_logs (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        user_name TEXT,
        action TEXT NOT NULL,
        resource_type TEXT,
        resource_id TEXT,
        details JSONB,
        ip_address TEXT,
        created_at BIGINT NOT NULL
      )
    ''');

    // جدول إعدادات النظام
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS system_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        description TEXT,
        updated_at BIGINT NOT NULL
      )
    ''');

    // جدول الإشعارات (SMS/Email) المجدولة
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS notifications (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,             -- sms / email
        recipient TEXT NOT NULL,        -- phone or email
        subject TEXT,
        message TEXT NOT NULL,
        scheduled_at BIGINT NOT NULL,
        status TEXT NOT NULL,           -- scheduled / sent / failed / cancelled
        related_type TEXT,              -- appointment
        related_id TEXT,
        created_at BIGINT NOT NULL,
        sent_at BIGINT,
        error TEXT
      )
    ''');

    // إدارة الغرف
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS rooms (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,            -- ward / icu / operation / isolation
        floor INTEGER,
        notes TEXT,
        created_at BIGINT NOT NULL,
        updated_at BIGINT
      )
    ''');

    await conn.execute('''
      CREATE TABLE IF NOT EXISTS beds (
        id TEXT PRIMARY KEY,
        room_id TEXT NOT NULL,
        label TEXT NOT NULL,
        status TEXT NOT NULL,          -- available / occupied / reserved / maintenance
        patient_id TEXT,
        occupied_since BIGINT,
        updated_at BIGINT,
        FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE
      )
    ''');

    await conn.execute('''
      CREATE TABLE IF NOT EXISTS bed_transfers (
        id TEXT PRIMARY KEY,
        patient_id TEXT NOT NULL,
        from_bed_id TEXT,
        to_bed_id TEXT NOT NULL,
        reason TEXT,
        created_at BIGINT NOT NULL
      )
    ''');

    // جدول الفواتير
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS invoices (
        id TEXT PRIMARY KEY,
        patient_id TEXT NOT NULL,
        patient_name TEXT NOT NULL,
        related_type TEXT,                 -- appointment / surgery / stay / order
        related_id TEXT,                   -- id of related entity
        items JSONB NOT NULL,              -- [{description, qty, unitPrice, total}]
        subtotal REAL NOT NULL,
        discount REAL NOT NULL DEFAULT 0,
        tax REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL,
        currency TEXT NOT NULL DEFAULT 'SAR',
        status TEXT NOT NULL,              -- draft / issued / paid / cancelled
        insurance_provider TEXT,
        insurance_policy TEXT,
        created_at BIGINT NOT NULL,
        updated_at BIGINT,
        paid_at BIGINT
      )
    ''');

    // جدول المدفوعات
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS payments (
        id TEXT PRIMARY KEY,
        invoice_id TEXT NOT NULL,
        amount REAL NOT NULL,
        method TEXT NOT NULL,             -- cash / card / transfer / insurance
        reference TEXT,
        created_at BIGINT NOT NULL,
        notes TEXT,
        FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE
      )
    ''');

    // جدول العمليات الجراحية
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS surgeries (
        id TEXT PRIMARY KEY,
        patient_id TEXT NOT NULL,
        patient_name TEXT NOT NULL,
        surgery_name TEXT NOT NULL,
        type TEXT NOT NULL,               -- elective / emergency / urgent
        status TEXT NOT NULL,             -- scheduled / inProgress / completed / cancelled / postponed
        scheduled_date BIGINT NOT NULL,
        start_time BIGINT,
        end_time BIGINT,
        operation_room_id TEXT,
        operation_room_name TEXT,
        surgeon_id TEXT NOT NULL,
        surgeon_name TEXT NOT NULL,
        assistant_surgeon_id TEXT,
        assistant_surgeon_name TEXT,
        anesthesiologist_id TEXT,
        anesthesiologist_name TEXT,
        nurse_ids JSONB,
        nurse_names JSONB,
        pre_operative_notes JSONB,
        operative_notes JSONB,
        post_operative_notes JSONB,
        diagnosis TEXT,
        procedure TEXT,
        notes TEXT,
        equipment JSONB,
        created_at BIGINT NOT NULL,
        updated_at BIGINT
      )
    ''');

    // جدول المستودع الطبي العام
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS medical_inventory (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,               -- equipment / supplies / consumables
        category TEXT,
        description TEXT,
        quantity INTEGER NOT NULL DEFAULT 0,
        min_stock_level INTEGER,
        unit TEXT,
        unit_price REAL,
        manufacturer TEXT,
        model TEXT,
        serial_number TEXT,
        purchase_date BIGINT,
        expiry_date BIGINT,
        location TEXT,
        status TEXT,                      -- available / inUse / maintenance / outOfOrder (للمعدات)
        last_maintenance_date BIGINT,
        next_maintenance_date BIGINT,
        supplier_id TEXT,
        supplier_name TEXT,
        created_at BIGINT NOT NULL,
        updated_at BIGINT
      )
    ''');

    // جدول الموردين
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS suppliers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        contact_person TEXT,
        email TEXT,
        phone TEXT,
        address TEXT,
        notes TEXT,
        created_at BIGINT NOT NULL,
        updated_at BIGINT
      )
    ''');

    // جدول طلبات الشراء
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS purchase_orders (
        id TEXT PRIMARY KEY,
        order_number TEXT NOT NULL UNIQUE,
        supplier_id TEXT,
        supplier_name TEXT,
        items JSONB NOT NULL,
        total_amount REAL NOT NULL,
        status TEXT NOT NULL,             -- draft / pending / approved / ordered / received / cancelled
        notes TEXT,
        requested_by TEXT,
        requested_date BIGINT,
        approved_by TEXT,
        approved_date BIGINT,
        ordered_date BIGINT,
        received_date BIGINT,
        created_at BIGINT NOT NULL,
        updated_at BIGINT
      )
    ''');

    // جدول سجلات الصيانة
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS maintenance_records (
        id TEXT PRIMARY KEY,
        equipment_id TEXT NOT NULL,
        equipment_name TEXT NOT NULL,
        maintenance_date BIGINT NOT NULL,
        maintenance_type TEXT NOT NULL,   -- scheduled / repair / inspection
        description TEXT,
        performed_by TEXT,
        cost REAL,
        next_maintenance_date BIGINT,
        created_at BIGINT NOT NULL,
        FOREIGN KEY (equipment_id) REFERENCES medical_inventory(id) ON DELETE CASCADE
      )
    ''');

    // جداول التمريض
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS nursing_tasks (
        id TEXT PRIMARY KEY,
        nurse_id TEXT NOT NULL,
        patient_id TEXT,
        patient_name TEXT,
        bed_id TEXT,
        room_id TEXT,
        type TEXT NOT NULL,               -- medication / vitalSigns / woundCare / patientCheck / documentation / other
        title TEXT NOT NULL,
        description TEXT,
        status TEXT NOT NULL,              -- pending / inProgress / completed / cancelled
        scheduled_at BIGINT NOT NULL,
        completed_at BIGINT,
        completed_by TEXT,
        result_data JSONB,
        created_at BIGINT NOT NULL,
        updated_at BIGINT
      )
    ''');

    await conn.execute('''
      CREATE TABLE IF NOT EXISTS nursing_notes (
        id TEXT PRIMARY KEY,
        nurse_id TEXT NOT NULL,
        nurse_name TEXT,
        patient_id TEXT NOT NULL,
        patient_name TEXT,
        bed_id TEXT,
        room_id TEXT,
        note TEXT NOT NULL,
        vital_signs JSONB,
        observations TEXT,
        created_at BIGINT NOT NULL,
        updated_at BIGINT
      )
    ''');

    AppLogger.info('Database tables created/verified');
    print('✅ Database tables ready');
  }

  Future<void> close() async {
    await _connection?.close();
    _connection = null;
    AppLogger.info('Database connection closed');
  }
}

