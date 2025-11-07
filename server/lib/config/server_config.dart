import 'dart:io';

class ServerConfig {
  static final ServerConfig _instance = ServerConfig._internal();
  factory ServerConfig() => _instance;
  ServerConfig._internal();

  late InternetAddress host;
  late int port;

  void load() {
    final env = _loadEnv();
    
    final hostStr = env['SERVER_HOST'] ?? env['HOST'] ?? '0.0.0.0';
    host = InternetAddress(hostStr);
    final portValue = env['PORT'] ?? env['SERVER_PORT'] ?? '8080';
    port = int.tryParse(portValue) ?? 8080;
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
}

