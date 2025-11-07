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

    AppLogger.info('Database tables created/verified');
    print('✅ Database tables ready');
  }

  Future<void> close() async {
    await _connection?.close();
    _connection = null;
    AppLogger.info('Database connection closed');
  }
}

