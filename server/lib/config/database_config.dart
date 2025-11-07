import 'dart:io';

class DatabaseConfig {
  static final DatabaseConfig _instance = DatabaseConfig._internal();
  factory DatabaseConfig() => _instance;
  DatabaseConfig._internal();

  late String host;
  late int port;
  late String database;
  late String user;
  late String password;

  void load() {
    final env = _loadEnv();
    
    host = env['DATABASE_HOST'] ?? 'localhost';
    port = int.tryParse(env['DATABASE_PORT'] ?? '5432') ?? 5432;
    database = env['DATABASE_NAME'] ?? 'shs_app';
    user = env['DATABASE_USER'] ?? 'postgres';
    password = env['DATABASE_PASSWORD'] ?? '';
  }

  Map<String, String> _loadEnv() {
    final env = <String, String>{};
    final file = File('.env');
    
    if (file.existsSync()) {
      final lines = file.readAsLinesSync();
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
        
        final index = trimmed.indexOf('=');
        if (index > 0) {
          final key = trimmed.substring(0, index).trim();
          final value = trimmed.substring(index + 1).trim();
          env[key] = value;
        }
      }
    }
    
    // إضافة متغيرات البيئة من النظام
    env.addAll(Platform.environment);
    
    return env;
  }

  String get connectionString => 
      'postgresql://$user:$password@$host:$port/$database';
}

