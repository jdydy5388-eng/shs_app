import 'dart:async';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'config/server_config.dart';
import 'config/database_config.dart';
import 'database/database_service.dart';
import 'routes/api_routes.dart';
import 'logger/app_logger.dart';
import 'utils/rate_limiter.dart';
import 'utils/audit_middleware.dart';

void main(List<String> args) async {
  try {
    print('🚀 Starting SHS Server...');
    print('📋 Loading configuration...');
    
    // تحميل الإعدادات
    DatabaseConfig().load();
    ServerConfig().load();
    print('✅ Configuration loaded');

    // الاتصال بقاعدة البيانات
    print('🔌 Connecting to database...');
    await DatabaseService().connection.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw TimeoutException(
          'Database connection timeout after 10 seconds. '
          'Please check if PostgreSQL is running and .env file is correct.',
          const Duration(seconds: 10),
        );
      },
    );
    AppLogger.info('Database initialized');
    print('✅ Database connected');

    // إنشاء Router
    print('🔧 Setting up API routes...');
    final router = ApiRoutes.createRouter();
    print('✅ Routes configured');

    // إضافة CORS headers و Security Middleware
    print('🔒 Adding middleware...');
    final handler = Pipeline()
        .addMiddleware(corsHeaders())
        .addMiddleware(rateLimitMiddleware()) // Rate Limiting
        .addMiddleware(auditMiddleware()) // Audit Logging
        .addMiddleware(logRequests())
        .addHandler(router);
    print('✅ Middleware added (CORS, Rate Limiting, Audit Logging)');

    // بدء الخادم
    print('🌐 Starting HTTP server...');
    final config = ServerConfig();
    final server = await io.serve(
      handler,
      config.host,
      config.port,
    );

    print('');
    print('═══════════════════════════════════════');
    print('✅ Server is running!');
    print('📍 Address: http://${server.address.host}:${server.port}');
    print('🔗 API: http://${server.address.host}:${server.port}/api');
    print('═══════════════════════════════════════');
    print('');
    
    AppLogger.info('Server running on http://${server.address.host}:${server.port}');
    AppLogger.info('API available at http://${server.address.host}:${server.port}/api');

    // إغلاق نظيف عند إيقاف الخادم
    ProcessSignal.sigint.watch().listen((signal) async {
      AppLogger.info('Shutting down server...');
      await server.close();
      await DatabaseService().close();
      exit(0);
    });
  } catch (e, stackTrace) {
    AppLogger.error('Failed to start server', e, stackTrace);
    // طباعة رسائل الخطأ بشكل مباشر لسهولة التشخيص في PowerShell
    stderr.writeln('Failed to start server: ' + e.toString());
    if (stackTrace != null) {
      stderr.writeln(stackTrace.toString());
    }
    exit(1);
  }
}

Middleware logRequests() {
  return (Handler handler) {
    return (Request request) async {
      final start = DateTime.now();
      final response = await Future.sync(() => handler(request));
      final duration = DateTime.now().difference(start);
      AppLogger.info(
        '${request.method} ${request.url.path} - ${response.statusCode} (${duration.inMilliseconds}ms)',
      );
      return response;
    };
  };
}

